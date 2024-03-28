
ANDROID_PROJECTS_DIR="."
ANDROID_API_VERSION="28"
JDK_DIR="$ANDROID_PROJECTS_DIR/jdk"
SDK_DIR="$ANDROID_PROJECTS_DIR/sdk"
PLATFORM_DIR="$SDK_DIR/platforms/api-$ANDROID_API_VERSION"
BUILD_TOOLS_DIR="$SDK_DIR/build-tools/api-$ANDROID_API_VERSION"


PROJECTS_DIR="$ANDROID_PROJECTS_DIR/projects"

PACKAGE_PREFIX_NAME="com.nusabyte.app"
PACKAGE_PREFIX_DIR="com/nusabyte/app"


function initProject {
	projectName="$1"
	appLabel="$2"
	packageDir="$PACKAGE_PREFIX_DIR/$projectName"

	cp -r template $PROJECTS_DIR/$projectName
	mkdir -p "$PROJECTS_DIR/$projectName/source/java/$packageDir"

	echo "    [i] Write AndroidManifest.xml"
	(cat > "$PROJECTS_DIR/$projectName/source/AndroidManifest.xml") << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="$PACKAGE_PREFIX_NAME.$projectName"
          versionCode="1"
          versionName="1.0">
    <uses-sdk android:minSdkVersion="$ANDROID_API_VERSION"/>
    <application android:label="$appLabel">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

	echo "    [i] Write MainActivity.java"
	(cat > "$PROJECTS_DIR/$projectName/source/java/$packageDir/MainActivity.java") << EOF
package ${PACKAGE_PREFIX_NAME}.${projectName};

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        TextView text = (TextView)findViewById(R.id.my_text);
        text.setText("Hello, world!");
    }
}
EOF

}


function buildProject {
	projectName=$1
	buildMode=$2
	packageDir="$PACKAGE_PREFIX_DIR/$projectName"
	
	mkdir -p \
		"$PROJECTS_DIR/$projectName/build/gen/" \
		"$PROJECTS_DIR/$projectName/build/obj/" \
		"$PROJECTS_DIR/$projectName/build/apk/"

	echo "    [*] Invoking aapt: generate R.java"
	$BUILD_TOOLS_DIR/aapt \
		package \
		-f \
		-m \
		-J "$PROJECTS_DIR/$projectName/build/gen/" \
		-S "$PROJECTS_DIR/$projectName/source/res" \
		-M "$PROJECTS_DIR/$projectName/source/AndroidManifest.xml" \
		-I "$PLATFORM_DIR/android.jar"
	[ $? -ne 0 ] && exit;

	echo "    [*] Invoking javac: compile java source files"
	find \
		$PROJECTS_DIR/$projectName/ \
		-name "*.java" \
		-type f \
		-print0 \
		| \
	xargs \
		-0 \
		$JDK_DIR/bin/javac \
			-classpath "$PLATFORM_DIR/android.jar" \
			-d "$PROJECTS_DIR/$projectName/build/obj/"

	[ $? -ne 0 ] && exit;

	echo "    [*] Invoking d8: generate dex files: $buildMode"
	if [ $buildMode == 'release' ]; then
		find \
			$PROJECTS_DIR/$projectName/build/obj/ \
			-name "*.class" \
			-type f \
			-print0 \
			| \
		xargs \
			-0 \
			$BUILD_TOOLS_DIR/d8 \
				--release \
				--lib "$PLATFORM_DIR/android.jar" \
				--output "$PROJECTS_DIR/$projectName/build/apk/"
	else
		find \
			$PROJECTS_DIR/$projectName/build/obj/ \
			-name "*.class" \
			-type f \
			-print0 \
			| \
		xargs \
			-0 \
			$BUILD_TOOLS_DIR/d8 \
				--debug \
				--lib "$PLATFORM_DIR/android.jar" \
				--output "$PROJECTS_DIR/$projectName/build/apk/"
	fi
	[ $? -ne 0 ] && exit;

	echo "    [*] Invoking aapt: generate unsigned.apk"
	$BUILD_TOOLS_DIR/aapt \
		package \
		-f \
		-S "$PROJECTS_DIR/$projectName/source/res" \
		-M "$PROJECTS_DIR/$projectName/source/AndroidManifest.xml" \
		-I "$PLATFORM_DIR/android.jar" \
		-F "$PROJECTS_DIR/$projectName/build/${projectName}.unsigned.apk" \
		"$PROJECTS_DIR/$projectName/build/apk/"
	[ $? -ne 0 ] && exit;

	if [ $buildMode == 'release' ]; then
		echo "    [*] Invoking zipalign: align unsigned.apk file"
		$BUILD_TOOLS_DIR/zipalign \
			-f \
			-p 4 \
			"$PROJECTS_DIR/$projectName/build/${projectName}.unsigned.apk" \
			"$PROJECTS_DIR/$projectName/build/${projectName}.aligned_unsigned.apk"
		[ $? -ne 0 ] && exit;
	fi
	
	echo "    [*] Invoking apksigner: sign aligned_unsigned.apk file"
	$BUILD_TOOLS_DIR/apksigner \
		sign \
		--ks "$ANDROID_PROJECTS_DIR/keystore.jks" \
		--ks-key-alias androidkey \
		--ks-pass pass:android \
		--key-pass pass:android \
		--out "$PROJECTS_DIR/$projectName/build/${projectName}.apk" \
		"$PROJECTS_DIR/$projectName/build/${projectName}.unsigned.apk"
	[ $? -ne 0 ] && exit;
	echo "    [v] Apk file saved to build/${projectName}.apk"
}


ARG_COMMAND=$1
ARG_PROJECT_NAME=$2
ARG_BUILD_MODE=${3:-'debug'}

if [[ $ARG_COMMAND == "init" ]]; then
	echo "  [-] Initializing project: $ARG_PROJECT_NAME"
	initProject $ARG_PROJECT_NAME "$ARG_BUILD_MODE"
	exit
elif [[ $ARG_COMMAND == "build" ]]; then
	echo "  [-] Building project: $ARG_PROJECT_NAME"
	buildProject $ARG_PROJECT_NAME "$ARG_BUILD_MODE"
	exit
else
	echo "  [!] Unknown command: $ARG_COMMAND"
	exit
fi
