#! /usr/bin/env bash

# -------------------------------- Config --------------------------------

export PKG_VERSION="0.1.1"

# ------------------------------- Functions ------------------------------

main_loop() {
    echo
    say_name

    if [ -z "$PROJ" ] || [ -z "$TRGT" ]; then
        echo -n "You must specify a directory containing a *.csproj file AND a target location."
        say_fail
        exit 1
    fi

    check_for_dotnet

    if [ $? -eq 0 ]; then compile_net_project; else exit 1; fi
    if [ $? -eq 0 ]; then transfer_files; else exit 1; fi
    if [ $? -eq 0 ]; then say_pass; create_pkg; else say_fail; exit 1; fi
    if [ $? -eq 0 ]; then
        echo -n "AppImageKit compression:"
        say_pass
        delete_temp_files
    else
        echo -n "AppImageKit compression:"
        say_fail
        exit 1
    fi
    if [ $? -eq 0 ]; then say_pass; else say_fail; exit 1; fi
    echo -n "Packaging complete:"
    say_pass
    echo "${green:-}New NET_Pkg created at $TRGT/$CSPROJ$EXTN${normal:-}"
    echo
}

check_for_dotnet() {
    check_path

    echo -n "Checking if .NET sdk is installed...";

    if [ -z "$LOC" ]; then
        say_warning
        $PKG_DIR/NET_Pkg.Template/usr/bin/dotnet-installer.sh -sdk
        check_path
        return 0
    else
        say_pass
        return 0
    fi

    echo -n ".NET sdk install failed"
    say_fail
    exit 1
}

check_path() {
    echo $PATH | grep -q  "$HOME/.local/share/dotnet/bin" 2> /dev/null
    ERR_CODE=$?

    if [ -f "$HOME/.local/share/dotnet/bin/dotnet-sdk" ] && [ $ERR_CODE -ne 0 ]; then
        echo -n ".NET detected but not in \$PATH. Adding for current session."
        export PATH=$PATH:$HOME/.local/share/dotnet/bin
        say_pass
    fi
}

start_installer() {
    $HERE/usr/bin/dotnet-installer.sh -sdk
    if [ $? -eq 0 ]; then
        start_app
    fi
}

compile_net_project() {
    cd $PROJ

    find_csproj
    if [ -z $VERB ]; then echo -n "Restoring .NET project dependencies..."; fi
    if ! [ -z $VERB ]; then dotnet restore; else dotnet restore >/dev/null; fi

    if [ $? -eq 0 ]; then
        if [ -z $VERB ]; then say_pass; fi
        if [ -z $VERB ]; then echo -n "Compiling .NET project..."; fi
        export CORE_VERS=$($PKG_DIR/tools/parse-csproj.py 2>&1 >/dev/null)
        if ! [ -z $VERB ]; then dotnet publish -f $CORE_VERS -c Release
        else dotnet publish -f $CORE_VERS -c Release >/dev/null; fi
    else
        if [ -z $VERB ]; then say_fail; fi
        echo "${red:-}Failed to restore .NET Core application dependencies.${normal:-}"
        echo
        exit 1
    fi

    if [ $? -eq 0 ]; then 
        if [ -z $VERB ]; then say_pass; fi
        cd $PKG_DIR
        return 0
    else
        if [ -z $VERB ]; then say_fail; fi
        echo "${red:-}Failed to complile .NET Core application.${normal:-}"
        echo
        exit 1
    fi
}

find_csproj() {
    cd $PROJ
    CSFILE=$(find . -name '*.csproj')
    LEN=${#CSFILE}
    export CSPROJ=${CSFILE:2:LEN-9}
}

transfer_files() {
    echo -n "Transferring files..."

    mkdir -p /tmp/NET_Pkg.Temp
    cp -r $PKG_DIR/NET_Pkg.Template/. /tmp/NET_Pkg.Temp
    mkdir -p /tmp/NET_Pkg.Temp/usr/share/app
    cp -r $PROJ/bin/Release/$CORE_VERS/publish/. /tmp/NET_Pkg.Temp/usr/share/app

    if [ -d "$PROJ/pkg.lib" ]; then
        cp -r $PROJ/pkg.lib/. /tmp/NET_Pkg.Temp/usr/lib
    fi

    touch /tmp/NET_Pkg.Temp/AppRun
    echo "#! /usr/bin/env bash" >> /tmp/NET_Pkg.Temp/AppRun
    echo >> /tmp/NET_Pkg.Temp/AppRun
    echo "# -------------------------------- Config --------------------------------" >> /tmp/NET_Pkg.Temp/AppRun
    echo >> /tmp/NET_Pkg.Temp/AppRun
    echo DLL_NAME=$CSPROJ >> /tmp/NET_Pkg.Temp/AppRun
    echo PKG_VERSION=$PKG_VERSION >> /tmp/NET_Pkg.Temp/AppRun
    echo >> /tmp/NET_Pkg.Temp/AppRun
    cat $PKG_DIR/tools/AppRun.sh >> /tmp/NET_Pkg.Temp/AppRun

    chmod +x /tmp/NET_Pkg.Temp/AppRun
    chmod -R +x /tmp/NET_Pkg.Temp/usr/bin

    rm /tmp/NET_Pkg.Temp/usr/share/app/$CSPROJ.pdb
}

create_pkg() {
    if ! [ -z $VERB ]; then appimagetool -n /tmp/NET_Pkg.Temp $TRGT/$CSPROJ$EXTN
    else appimagetool -n /tmp/NET_Pkg.Temp $TRGT/$CSPROJ$EXTN >/dev/null; fi
}

delete_temp_files() {
    echo -n "Deleting temporary files..."
    rm -r /tmp/NET_Pkg.Temp
}

check_path() {
    echo $PATH | grep -q  "$HOME/.local/share/dotnet/bin" 2> /dev/null
    ERR_CODE=$?

    if [ -f "$HOME/.local/share/dotnet/bin/dotnet" ] && [ $ERR_CODE -ne 0 ]; then
        echo "${yellow:-}.NET detected but not in \$PATH. Adding for current session.${normal:-}"
        export PATH=$PATH:$HOME/.local/share/dotnet/bin
    fi
}

get_colors() {
    # See if stdout is a terminal
    if [ -t 1 ]; then
        # see if it supports colors
        ncolors=$(tput colors)
        if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
            export bold="$(tput bold       || echo)"
            export normal="$(tput sgr0     || echo)"
            export black="$(tput setaf 0   || echo)"
            export red="$(tput setaf 1     || echo)"
            export green="$(tput setaf 2   || echo)"
            export yellow="$(tput setaf 3  || echo)"
            export blue="$(tput setaf 4    || echo)"
            export magenta="$(tput setaf 5 || echo)"
            export cyan="$(tput setaf 6    || echo)"
            export white="$(tput setaf 7   || echo)"
        fi
    fi
}

say_name() {
    echo -n "------------------ ${cyan:-}"
    echo -n "${bold:-}NET_Pkg.Tool $PKG_VERSION"
    echo "${normal:-} -------------------"
}

say_pass() {
    echo "${bold:-} [ ${green:-}PASS${white:-} ]${normal:-}"
}

say_warning() {
    echo "${bold:-} [ ${yellow:-}FAIL${white:-} ]${normal:-}"
}

say_fail() {
    echo "${bold:-} [ ${red:-}FAIL${white:-} ]${normal:-}"
}

# ------------------------------- Variables ------------------------------

source /etc/os-release
export OS_NAME=$NAME
export OS_ID=$ID
export OS_VERSION=$VERSION_ID
export OS_CODENAME=$VERSION_CODENAME
export OS_PNAME=$PRETTY_NAME
export PKG_VERSION=$PKG_VERSION
export LOC="$(which dotnet)"

export PKG_DIR=$(dirname $(readlink -f "${0}"))
export PROJ=$1
export TRGT=$2
export EXTN=".NET"
get_colors

# --------------------------------- Args ---------------------------------

if [ "$3" == "-v" ] || [ "$1" == "-verbose" ]; then
    VERB="true";
    export VERB=$VERB
fi

if [ "$1" == "-d" ] || [ "$1" == "-dir" ]; then
    echo ".NET installed at: $LOC"
    exit 0
elif [ "$1" == "-h" ] || [ "$1" == "-help" ]; then
    $PKG_DIR/tools/pkg-tool-help.sh
    exit 0
fi

# --------------------------------- Init ---------------------------------

main_loop
