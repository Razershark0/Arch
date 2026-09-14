pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string enPath: Caching.serpantinumDir + "/assets/languages/en.json"
    property var translations: ({})
    property bool isReady: false

    FileView {
        id: langFile
        path: root.enPath
        onLoaded: {
            try {
                root.translations = JSON.parse(text());
            } catch (e) {
                root.translations = {};
            }
            root.isReady = true;
        }
    }

    function t(key, args) {
        let parts = key.split('.');
        let current = root.translations;
        for (let i = 0; i < parts.length; i++) {
            if (current === null || current === undefined || current[parts[i]] === undefined) {
                return key;
            }
            current = current[parts[i]];
        }
        if (typeof current !== "string") return key;

        if (args && typeof args === "object") {
            for (let k in args) {
                current = current.replace(new RegExp("\\{" + k + "\\}", "g"), args[k]);
            }
        }
        return current;
    }
}
