#!/bin/bash
# created by Leon 2015.5.18
# version: 0.2
# Usage: resign.sh xxx.ipa

function entitlements()
{
	entitle="$1"
	plist="$2"

	/usr/libexec/PlistBuddy -x -c "print :Entitlements" /dev/stdin <<< $(security cms -D -i $PROVISION_FILE) > "$entitle"
	/usr/libexec/PlistBuddy -c "Set :get-task-allow false" "$entitle"

	localID=$(/usr/libexec/PlistBuddy -c 'print :com.apple.developer.team-identifier' "$entitle")
	appID=$(/usr/libexec/PlistBuddy -c 'print :CFBundleIdentifier' "$MAIN_APP_PATH/Info.plist")

	/usr/libexec/PlistBuddy -c "Set :application-identifier $localID.$appID" "$entitle"
	/usr/libexec/PlistBuddy -c "Set :keychain-access-groups:0 $localID.$appID" "$entitle"
	# /usr/libexec/PlistBuddy -c "Add :keychain-access-groups:0 string $localID.com.smartdevicelink.smartdevicelink" "$ENTITLEMENTS_FILE"
}

function resign()
{	
	appPath="$1"
		 
	## copy new provision profile
	cp "$PROVISION_FILE" "$appPath/embedded.mobileprovision"	

	## codesign with new certificate and provision
	rm -rf "$appPath/_CodeSignature/"
	/usr/bin/codesign -fs "$CERTIFICATE" --no-strict --entitlements="$ENTITLEMENTS_FILE" "$appPath"
}



if ([ "$1" == "-h" ]); then
	echo "Usage: resign.sh xxx.ipa"
	exit
elif ! ([ -f "$1" ]); then
	echo \"${1}\" not exist
	exit
fi


IN_FILE="$1"
OUT_FILE_NAME=$(basename "$1")_signed.ipa
WORK_PATH="resign_tmp"

ENTITLEMENTS_FILE=$WORK_PATH/entitlements.plist
PROVISION_FILE=FORD_InHouse_WildCard.mobileprovision
CERTIFICATE="iPhone Distribution: FORD MOTOR (CHINA) LTD"


rm -f "$OUT_FILE_NAME"

## unzip
echo "unzip $IN_FILE..."
unzip -q "$IN_FILE" -d "$WORK_PATH"
MAIN_APP_PATH="$WORK_PATH/Payload/"$(ls "$WORK_PATH/Payload")

## generate entitlements.plist
echo "generate entitlements.plist..."
entitlements "$ENTITLEMENTS_FILE" "$MAIN_APP_PATH/Info.plist"

## process frameworks
if ([ -d "$MAIN_APP_PATH"/Frameworks/ ]); then
	echo "start resign frameworks..."
	for framework in "$MAIN_APP_PATH"/Frameworks/*.framework
	do
		resign "$framework"
	done

	# for dylib in "$MAIN_APP_PATH"/Frameworks/*.dylib
	# do
	# 	resign "$dylib"
	# done
fi

## process plugins
if ([ -d "$MAIN_APP_PATH"/PlugIns/ ]); then
	echo "start resign plugins..."
	for appex in "$MAIN_APP_PATH"/PlugIns/*.appex
	do
		resign "$appex"
		## app in appex needn't resign!
		# for j in "$i"/*.app
		# do
		# 	resign "$j"
		# done
	done
fi


## resign
echo "start resign main app..."
resign "$MAIN_APP_PATH"

## package
echo "repackage..."
cd "$WORK_PATH"
zip -qry "../$OUT_FILE_NAME" "."
cd ..
rm -rf "$WORK_PATH"

echo "done"

# open folder in finder
open "$(pwd)"

