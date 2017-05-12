#! /usr/bin/env bash

# -------------------------------- Config --------------------------------

export PKG_VERSION="0.2.1"

# ------------------------------- Functions ------------------------------

main_loop() {
    say_hello

    if [[ -z "$PROJ" ]] || [[ -z "$TRGT" ]]; then
        echo -n "You must specify a directory containing a *.csproj file AND a target location."
        say_fail
        exit 1
    fi

    check_for_dotnet

    if [[ $? -eq 0 ]]; then compile_net_project; else exit 1; fi
    if [[ $? -eq 0 ]]; then transfer_files; else exit 1; fi
    if [[ $? -eq 0 ]]; then say_pass; create_pkg; else say_fail; exit 1; fi
    if [[ $? -eq 0 ]]; then
        echo -n "AppImageKit compression:"
        say_pass
        delete_temp_files
    else
        echo -n "AppImageKit compression:"
        say_fail
        exit 1
    fi
    if [[ $? -eq 0 ]]; then say_pass; else say_fail; exit 1; fi
    echo -n "Packaging complete:"
    say_pass
    echo "${green:-}New NET_Pkg created at $TRGT/$CSPROJ$EXTN${normal:-}"
    echo
}

check_for_dotnet() {
    check_for_sdk
    if [[ $? != 0 ]]; then
        while true; do
            read -p "Would you like to download & install the .NET sdk? (y/n): " yn
            case $yn in
                [Yy]* ) start_installer; return 0;;
                [Nn]* ) echo "${red:-}User aborted the application.${normal:-}"; echo; exit 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        return 0
    fi
}

check_for_sdk() {
    echo -n "Checking if .NET sdk is installed..."

    mkdir /tmp/.net-sdk-test && cd /tmp/.net-sdk-test
    dotnet new sln &> /dev/null

    if [[ $? -eq 0 ]]; then
        say_pass
        cd $PKG_DIR
        rm -r /tmp/.net-sdk-test
        return 0;
    else
        say_warning
        cd $PKG_DIR
        rm -r /tmp/.net-sdk-test
        return 1;
    fi;
}

start_installer() {
    $PKG_DIR/NET_Pkg.Template/usr/bin/dotnet-installer.sh -sdk
    if [[ $? -eq 0 ]]; then
        return 0
    else
        exit 1
    fi
}

compile_net_project() {
    cd $PROJ

    find_csproj
    if [[ -z $VERB ]]; then echo -n "Restoring .NET project dependencies..."; fi
    if ! [[ -z $VERB ]]; then dotnet restore; else dotnet restore >/dev/null; fi

    if [[ $? -eq 0 ]]; then
        if [[ -z $VERB ]]; then say_pass; fi
        if [[ -z $VERB ]]; then echo -n "Compiling .NET project..."; fi
        export CORE_VERS=$($PKG_DIR/tools/parse-csproj.py 2>&1 >/dev/null)
        if ! [[ -z $VERB ]]; then dotnet publish -f $CORE_VERS -c Release
        else dotnet publish -f $CORE_VERS -c Release >/dev/null; fi
    else
        if [[ -z $VERB ]]; then say_fail; fi
        echo "${red:-}Failed to restore .NET Core application dependencies.${normal:-}"
        echo
        exit 1
    fi

    if [[ $? -eq 0 ]]; then 
        if [[ -z $VERB ]]; then say_pass; fi
        cd $PKG_DIR
        return 0
    else
        if [[ -z $VERB ]]; then say_fail; fi
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

    if [[ -d "$PROJ/pkg.lib" ]]; then
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
    if ! [[ -z $VERB ]]; then appimagetool -n /tmp/NET_Pkg.Temp $TRGT/$CSPROJ$EXTN
    else appimagetool -n /tmp/NET_Pkg.Temp $TRGT/$CSPROJ$EXTN &> /dev/null; fi
}

delete_temp_files() {
    if [[ -z $NO_DEL ]]; then
        echo -n "Deleting temporary files..."
        rm -r /tmp/NET_Pkg.Temp
    fi
}

check_path() {
    echo $PATH | grep -q  "$HOME/.local/share/dotnet/bin" 2> /dev/null
    ERR_CODE=$?

    if [[ -f "$HOME/.local/share/dotnet/bin/dotnet" ]] && [[ $ERR_CODE -ne 0 ]]; then
        echo "${yellow:-}.NET detected but not in \$PATH. Adding for current session.${normal:-}"
        export PATH=$HOME/.local/share/dotnet/bin:$PATH
    fi
}

force_install() {
    echo -n "Checking if .NET sdk is installed..."
    check_for_sdk &> /dev/null
    if [[ $? -eq 0 ]]; then 
        if [[ -f "$HOME/.local/share/dotnet/bin/dotnet" ]] && [[ -f "$HOME/.local/share/dotnet/bin/dotnet-sdk" ]]
            then say_fail; echo ".NET sdk already installed by NET_Pkg installer."
        else
            say_warning
            while true; do
                read -p ".NET sdk detected. Would you still like to install the sdk locally? (y/n): " yn
                case $yn in
                    [Yy]* ) start_installer; return 0;;
                    [Nn]* ) echo "${red:-}User aborted the application.${normal:-}"; echo; exit 1;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi
    else
        say_warning
        start_installer
    fi
}

get_colors() {
    # See if stdout is a terminal
    if [[ -t 1 ]]; then
        # see if it supports colors
        ncolors=$(tput colors)
        if [[ -n "$ncolors" ]] && [[ $ncolors -ge 8 ]]; then
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

say_hello() {
    echo
    echo -n "--------------------- ${cyan:-}"
    echo -n "${bold:-}NET_Pkg $PKG_VERSION"
    echo "${normal:-} ---------------------"
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
export LOC="$(which dotnet 2> /dev/null)"

export PKG_DIR=$(dirname $(readlink -f "${0}"))
export PROJ=$1
export TRGT=$2
export EXTN=".NET"
get_colors

chmod -R +x $PKG_DIR/tools
chmod -R +x $PKG_DIR/NET_Pkg.Template/usr/bin

# --------------------------------- Args ---------------------------------

if [[ "$3" == "-v" ]] || [[ "$1" == "--verbose" ]]; then
    export VERB="true"
elif [[ -z "$1" ]]; then
    $PKG_DIR/tools/pkg-tool-help.sh
    exit 0
fi

if [[ "$1" == "-d" ]] || [[ "$1" == "--dir" ]]; then
    if [[ -z "$LOC" ]]; then NET="${red:-}not installed${normal:-}"
    else NET="$(dirname $LOC)"; fi
    echo ".NET location: $NET"
    exit 0
elif [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    $PKG_DIR/tools/pkg-tool-help.sh
    exit 0
elif [[ "$1" == "--install-sdk" ]]; then
    say_hello
    force_install
    exit 0
fi

# --------------------------------- Init ---------------------------------

main_loop
