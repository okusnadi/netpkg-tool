#! /usr/bin/env bash

if [ -z "$LOC" ]; then LOC="${cyan:-}not installed${normal:-}"; fi

echo
echo -n "--------------------- ${cyan:-}"
echo -n "${bold:-}NET_Pkg $PKG_VERSION"
echo "${normal:-} ---------------------"
echo
echo "           App: $DLL_NAME.dll"
echo "            OS: $OS_PNAME"
echo " .NET location: $(dirname $LOC)"
echo
echo "        Optional Arguments:"
echo " --npk-verbose or --npk-v : Verbose output"
echo "    --npk-help or --npk-h : Help menu (this page)"
echo "     --npk-dir or --npk-d : View location of .NET runtime"
echo
echo "---------------------------------------------------------"
echo

exit 0
