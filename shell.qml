import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    // Couleurs/dimensions globales du prototype.
    // Je garde tes dimensions actuelles.
    readonly property int frameSize: 18
    readonly property int barHeight: 86
    readonly property int cornerRadius: 34
    property var pywal: ({
        special: {
            background: "#1e1e2e",
            foreground: "#cdd6f4",
            cursor: "#cdd6f4"
        },
        colors: {
            color1: "#f38ba8",
            color5: "#f5c2e7",
            color8: "#a6adc8"
        }
    })
    readonly property color bg: pywal.special.background
    readonly property color fg: pywal.special.foreground
    readonly property color muted: pywal.colors.color8
    readonly property color active: pywal.colors.color5
    readonly property color hover: pywal.colors.color1

    // À adapter si tu veux viser un autre écran.
    // Chez toi, bspwmrc met les desktops 1 2 3 4 sur eDP-1.
    property string mainMonitor: "eDP-1"
    property var desktopNames: ["1", "2", "3", "4"]
    property string currentDesktop: "1"
    property bool menuOpen: false
    property bool dockOpen: false
    property bool volumeMenuOpen: false
    property bool audioDetailsOpen: false
    property bool playerMenuOpen: false
    property bool powerDockOpen: false
    property bool sideDockOpen: false
    property string sideMenuType: ""
    property string wifiSearch: ""
    property var audioInfo: ({
        sinkVolume: 0,
        sourceVolume: 0,
        sinkMuted: false,
        sourceMuted: false,
        sinks: [],
        sources: []
    })
    property var playerInfo: ({
        available: false,
        status: "Stopped",
        title: "Nothing playing",
        artist: "",
        album: "",
        player: "",
        artUrl: ""
    })
    property var batteryInfo: ({
        available: false,
        percentage: 0,
        status: "Unknown",
        charging: false,
        plugged: false,
        time: "",
        detail: "",
        icon: "󰂑"
    })
    property var sideInfo: ({
        wifi: { on: false, current: { ssid: "offline", signal: 0, connected: false }, networks: [] },
        bluetooth: { powered: false, connected: [], devices: [] },
        ram: { percent: 0, text: "" },
        disk: { percent: 0, free: "" },
        cpu: { percent: 0 },
        gpu: { available: false, percent: 0, temp: 0, memory: "" },
        temperature: { celsius: 0 }
    })

    function refreshDesktop() {
        currentDesktopProcess.running = true;
    }

    function switchDesktop(name) {
        switchDesktopProcess.command = ["bspc", "desktop", "-f", name];
        switchDesktopProcess.running = true;
    }

    function runMenuCommand(command) {
        menuOpen = false;
        menuCommandProcess.command = ["bash", "-lc", command];
        menuCommandProcess.running = true;
    }

    function runDockCommand(command) {
        dockOpen = false;
        menuCommandProcess.command = ["bash", "-lc", command];
        menuCommandProcess.running = true;
    }

    function runPowerCommand(command) {
        powerDockOpen = false;
        menuCommandProcess.command = ["bash", "-lc", command];
        menuCommandProcess.running = true;
    }

    function refreshAudio() {
        audioRefreshProcess.running = true;
    }

    function runAudioCommand(command) {
        audioCommandProcess.command = ["bash", "-lc", command];
        audioCommandProcess.running = true;
    }

    function refreshPlayer() {
        playerRefreshProcess.running = true;
    }

    function runPlayerCommand(command) {
        playerCommandProcess.command = ["bash", "-lc", command];
        playerCommandProcess.running = true;
    }

    function refreshBattery() {
        batteryRefreshProcess.running = true;
    }

    function refreshSideInfo() {
        sideRefreshProcess.running = true;
    }

    function runSideCommand(command) {
        sideCommandProcess.command = ["bash", "-lc", command];
        sideCommandProcess.running = true;
    }

    function sideMetricValue(kind) {
        if (kind === "wifi") return sideInfo.wifi.current.connected ? sideInfo.wifi.current.signal + "%" : (sideInfo.wifi.on ? "on" : "off");
        if (kind === "bluetooth") return sideInfo.bluetooth.connected.length > 0 ? sideInfo.bluetooth.connected.length + "" : (sideInfo.bluetooth.powered ? "on" : "off");
        if (kind === "ram") return sideInfo.ram.percent + "%";
        if (kind === "disk") return sideInfo.disk.free;
        if (kind === "cpu") return sideInfo.cpu.percent + "%";
        if (kind === "gpu") return sideInfo.gpu.available ? sideInfo.gpu.percent + "%" : "--";
        if (kind === "temp") return sideInfo.temperature.celsius + "°";
        return "";
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function filteredWifiNetworks() {
        const query = wifiSearch.toLowerCase().trim();
        const networks = sideInfo.wifi.networks || [];
        const filtered = query.length === 0
            ? networks
            : networks.filter(function(n) { return n.ssid.toLowerCase().indexOf(query) !== -1; });
        return filtered.slice(0, 8);
    }

    Process {
        id: currentDesktopProcess
        command: ["bspc", "query", "-D", "-d", "focused", "--names"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                if (value.length > 0)
                    currentDesktop = value;
            }
        }
    }

    Process {
        id: switchDesktopProcess
        running: false

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: refreshDesktop()
    }

    Process {
        id: menuCommandProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: audioRefreshProcess
        command: ["python3", "/home/arnaud/.config/quickshell/scripts/audio-state.py"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    if (parsed.sinks && parsed.sources)
                        audioInfo = parsed;
                } catch (e) {
                    console.warn("Could not parse audio state:", e);
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: audioCommandProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: refreshAudio()
    }

    Process {
        id: playerRefreshProcess
        command: ["python3", "/home/arnaud/.config/quickshell/scripts/player-state.py"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    playerInfo = parsed;
                } catch (e) {
                    console.warn("Could not parse player state:", e);
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: playerCommandProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: refreshPlayer()
    }

    Process {
        id: batteryRefreshProcess
        command: ["python3", "/home/arnaud/.config/quickshell/scripts/battery-state.py"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    batteryInfo = parsed;
                } catch (e) {
                    console.warn("Could not parse battery state:", e);
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: sideRefreshProcess
        command: ["python3", "/home/arnaud/.config/quickshell/scripts/side-state.py"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    sideInfo = parsed;
                } catch (e) {
                    console.warn("Could not parse side dock state:", e);
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: sideCommandProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: refreshSideInfo()
    }

    FileView {
        id: pywalFile
        path: Qt.resolvedUrl("/home/arnaud/.cache/wal/colors.json")
        blockLoading: true
        watchChanges: true

        Component.onCompleted: loadPywalColors()
        onTextChanged: loadPywalColors()
        onFileChanged: reload()

        function loadPywalColors() {
            try {
                const parsed = JSON.parse(text());
                if (parsed.special && parsed.colors)
                    pywal = parsed;
            } catch (e) {
                console.warn("Could not load pywal colors:", e);
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: refreshDesktop()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: refreshAudio()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: refreshPlayer()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: refreshBattery()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: refreshSideInfo()
    }

    Timer {
        id: menuCloseTimer
        interval: 260
        repeat: false
        onTriggered: menuOpen = false
    }

    Timer {
        id: volumeCloseTimer
        interval: 260
        repeat: false
        onTriggered: {
            volumeMenuOpen = false;
            audioDetailsOpen = false;
        }
    }

    Timer {
        id: playerCloseTimer
        interval: 260
        repeat: false
        onTriggered: playerMenuOpen = false
    }

    Timer {
        id: dockCloseTimer
        interval: 280
        repeat: false
        onTriggered: dockOpen = false
    }

    Timer {
        id: powerDockCloseTimer
        interval: 280
        repeat: false
        onTriggered: powerDockOpen = false
    }

    Timer {
        id: sideDockCloseTimer
        interval: 280
        repeat: false
        onTriggered: {
            sideDockOpen = false;
            sideMenuType = "";
            wifiSearch = "";
        }
    }

    // Barre principale en haut.
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: barHeight
        color: bg

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: 0
            spacing: 16

            Rectangle {
                width: 54
                height: 54
                radius: 14
                color: menuOpen ? active : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: menuOpen ? bg : fg
                    font.pixelSize: 42
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        menuCloseTimer.stop();
                        menuOpen = true;
                    }
                    onExited: menuCloseTimer.restart()
                    onClicked: menuOpen = true
                }
            }

            Text {
                text: "arnaud-laptop"
                color: muted
                font.pixelSize: 32
                font.family: "Annotation Mono"
            }

            RowLayout {
                spacing: 8

                Repeater {
                    model: desktopNames

                    Rectangle {
                        required property string modelData
                        readonly property bool selected: modelData === currentDesktop

                        width: 48
                        height: 48
                        radius: 8
                        color: selected ? active : "transparent"
                        border.color: selected ? active : fg
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: selected ? bg : fg
                            font.pixelSize: 28
                            font.bold: true
                            font.family: "Annotation Mono"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switchDesktop(modelData)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 200
                height: 46
                radius: 16
                color: bg
                border.color: batteryInfo.charging || batteryInfo.plugged ? active : muted
                border.width: 1
                opacity: batteryInfo.available ? 1 : 0.65

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: batteryInfo.icon
                        color: batteryInfo.charging || batteryInfo.plugged ? active : fg
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        text: batteryInfo.available ? batteryInfo.percentage + "%" : "--%"
                        color: fg
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Annotation Mono"
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        radius: 1
                        color: muted
                        opacity: 0.5
                        visible: batteryInfo.time.length > 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: batteryInfo.time
                        color: muted
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Annotation Mono"
                        elide: Text.ElideRight
                        visible: batteryInfo.time.length > 0
                    }
                }

                HoverHandler { id: batteryHover }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: refreshBattery()
                }
            }


            Rectangle {
                width: 360
                height: 46
                radius: 16
                color: playerHover.hovered ? hover : "transparent"
                border.color: playerInfo.status === "Playing" ? active : muted
                border.width: 1
                opacity: playerInfo.available ? 1 : 0.65

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 12
                        color: playerButtonMouse.containsMouse ? active : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: playerInfo.status === "Playing" ? "" : ""
                            color: playerButtonMouse.containsMouse ? bg : fg
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            id: playerButtonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: runPlayerCommand("playerctl play-pause")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2

                        Text {
                            Layout.fillWidth: true
                            text: playerInfo.available ? playerInfo.title : "Nothing playing"
                            color: fg
                            font.pixelSize: 16
                            font.bold: true
                            font.family: "Annotation Mono"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: playerInfo.artist.length > 0 ? playerInfo.artist : playerInfo.player
                            color: muted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: playerInfo.available
                        }
                    }
                }

                HoverHandler {
                    id: playerHover
                    onHoveredChanged: {
                        if (hovered) {
                            playerCloseTimer.stop();
                            playerMenuOpen = true;
                            refreshPlayer();
                        } else {
                            playerCloseTimer.restart();
                        }
                    }
                }
            }

            Rectangle {
                width: 118
                height: 46
                radius: 16
                color: volumeMenuOpen ? active : "transparent"
                border.color: volumeMenuOpen ? active : muted
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: audioInfo.sinkMuted ? "󰝟" : "󰕾"
                        color: volumeMenuOpen ? bg : fg
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        text: audioInfo.sinkVolume + "%"
                        color: volumeMenuOpen ? bg : fg
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Annotation Mono"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        volumeCloseTimer.stop();
                        volumeMenuOpen = true;
                        refreshAudio();
                    }
                    onExited: volumeCloseTimer.restart()
                    onClicked: runAudioCommand("pactl set-sink-mute @DEFAULT_SINK@ toggle")
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y > 0)
                            runAudioCommand("pactl set-sink-volume @DEFAULT_SINK@ +5%");
                        else
                            runAudioCommand("pactl set-sink-volume @DEFAULT_SINK@ -5%");
                    }
                }
            }

            Rectangle {
                width: 255
                height: 46
                radius: 16
                color: bg
                border.color: muted
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        id: dateLabel
                        Layout.preferredWidth: 92
                        horizontalAlignment: Text.AlignHCenter
                        color: muted
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Annotation Mono"
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        radius: 1
                        color: muted
                        opacity: 0.55
                    }

                    Text {
                        id: clock
                        Layout.preferredWidth: 118
                        horizontalAlignment: Text.AlignHCenter
                        color: fg
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Annotation Mono"
                    }
                }

                function updateDateTime() {
                    const now = new Date();
                    dateLabel.text = now.toLocaleDateString(Qt.locale(), "dd/MM");
                    clock.text = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss");
                }

                Component.onCompleted: updateDateTime()

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: parent.updateDateTime()
                }
            }
        }
    }

    // Menu playerctl : dropdown en Y sous le widget média.
    PanelWindow {
        anchors {
            top: true
            right: true
        }

        margins {
            top: 0
            right: 380
        }

        implicitWidth: 420 + 2 * cornerRadius
        implicitHeight: 280
        color: "transparent"
        mask: Region { item: playerCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: playerCard
                width: 420 + 2 * cornerRadius
                height: 230 + cornerRadius
                readonly property int bodyX: cornerRadius
                readonly property int bodyWidth: 420
                readonly property int bodyHeight: 230
                readonly property int playerRadius: 24
                readonly property int concaveRadius: cornerRadius
                y: playerMenuOpen ? 0 : -height - 12
                opacity: playerMenuOpen ? 1 : 0

                Behavior on y {
                    NumberAnimation { duration: 400; easing.type: playerMenuOpen ? Easing.OutCubic : Easing.InCubic }
                }

                Behavior on opacity {
                    NumberAnimation { duration: playerMenuOpen ? 100 : 200; easing.type: Easing.OutCubic }
                }

                Canvas {
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = playerCard.playerRadius;
                        const cr = playerCard.concaveRadius;
                        const x0 = playerCard.bodyX;
                        const w = playerCard.bodyWidth;
                        const h = playerCard.bodyHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Corps : haut droit pour être connecté à la barre,
                        // coins bas arrondis vers l'extérieur.
                        ctx.beginPath();
                        ctx.moveTo(x0, 0);
                        ctx.lineTo(x0 + w, 0);
                        ctx.lineTo(x0 + w, h - r);
                        ctx.quadraticCurveTo(x0 + w, h, x0 + w - r, h);
                        ctx.lineTo(x0 + r, h);
                        ctx.quadraticCurveTo(x0, h, x0, h - r);
                        ctx.lineTo(x0, 0);
                        ctx.closePath();
                        ctx.fill();

                        // Raccords additifs haut gauche/droite : pas des cutouts,
                        // ils ajoutent du bg pour lisser la transition avec la barre.
                        ctx.beginPath();
                        ctx.moveTo(x0, 0);
                        ctx.lineTo(x0 - cr, 0);
                        ctx.arc(x0 - cr, cr, cr, -Math.PI / 2, 0, false);
                        ctx.lineTo(x0, 0);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(x0 + w, 0);
                        ctx.lineTo(x0 + w + cr, 0);
                        ctx.arc(x0 + w + cr, cr, cr, -Math.PI / 2, Math.PI, true);
                        ctx.lineTo(x0 + w, 0);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                RowLayout {
                    width: playerCard.bodyWidth - 40
                    height: playerCard.bodyHeight - 40
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: playerCard.bodyX + 20
                    anchors.topMargin: 20
                    spacing: 16

                    Rectangle {
                        width: 112
                        height: 112
                        radius: 18
                        color: hover
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: playerInfo.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: playerInfo.artUrl.length > 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: fg
                            font.pixelSize: 42
                            visible: playerInfo.artUrl.length === 0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        height: parent.height
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: playerInfo.available ? playerInfo.title : "Nothing playing"
                            color: fg
                            font.pixelSize: 20
                            font.bold: true
                            font.family: "Annotation Mono"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: playerInfo.artist.length > 0 ? playerInfo.artist : playerInfo.player
                            color: muted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: playerInfo.album
                            color: muted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: playerInfo.album.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    { icon: "󰒮", command: "playerctl previous" },
                                    { icon: playerInfo.status === "Playing" ? "" : "", command: "playerctl play-pause" },
                                    { icon: "󰒭", command: "playerctl next" },
                                    { icon: "", command: "playerctl stop" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    height: 42
                                    radius: 14
                                    color: playerMenuButtonMouse.containsMouse ? hover : "transparent"
                                    border.color: muted
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: fg
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: playerMenuButtonMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: runPlayerCommand(modelData.command)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 12
                                color: seekBackMouse.containsMouse ? hover : "transparent"
                                border.color: muted
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "󰓕 -10s"; color: fg; font.pixelSize: 12 }
                                MouseArea { id: seekBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: runPlayerCommand("playerctl position 10-") }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 12
                                color: seekForwardMouse.containsMouse ? hover : "transparent"
                                border.color: muted
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "+10s 󰓒"; color: fg; font.pixelSize: 12 }
                                MouseArea { id: seekForwardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: runPlayerCommand("playerctl position 10+") }
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            playerCloseTimer.stop();
                            playerMenuOpen = true;
                            refreshPlayer();
                        } else {
                            playerCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Menu qui descend depuis l'icône Arch de la barre.
    PanelWindow {
        anchors {
            top: true
            left: true
        }

        margins {
            top: -5
            left: 0
        }

        implicitWidth: 400 + cornerRadius
        implicitHeight: 420 + cornerRadius + 20
        color: "transparent"

        // Important: sinon cette fenêtre transparente capture les clics sur
        // toute la bande gauche de l'écran. Le masque limite l'input au menu.
        mask: Region { item: menuCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: menuCard
                width: parent.width
                height: contentHeight + concaveRadius
                readonly property int contentHeight: 420
                readonly property int menuRadius: 24
                readonly property int concaveRadius: cornerRadius
                readonly property int menuWidth: width - concaveRadius
                readonly property real hiddenY: -height - 12
                y: hiddenY
                opacity: 0
                state: menuOpen ? "open" : "closed"

                states: [
                    State {
                        name: "open"
                        PropertyChanges { target: menuCard; y: 0; opacity: 1 }
                    },
                    State {
                        name: "closed"
                        PropertyChanges { target: menuCard; y: menuCard.hiddenY; opacity: 0 }
                    }
                ]

                transitions: [
                    Transition {
                        from: "closed"
                        to: "open"
                        NumberAnimation {
                            properties: "y"
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            properties: "opacity"
                            duration: 0
                            easing.type: Easing.OutCubic
                        }
                    },
                    Transition {
                        from: "open"
                        to: "closed"
                        NumberAnimation {
                            properties: "y"
                            duration: 400
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            properties: "opacity"
                            duration: 1000
                            easing.type: Easing.InCubic
                        }
                    }
                ]

                Canvas {
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = menuCard.menuRadius;
                        const cr = menuCard.concaveRadius;
                        const w = menuCard.menuWidth;
                        const h = menuCard.contentHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Corps du menu : rectangle bg, avec seulement le coin
                        // bas-droit arrondi vers l'extérieur.
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(w, 0);
                        ctx.lineTo(w, h - r);
                        ctx.quadraticCurveTo(w, h, w - r, h);
                        ctx.lineTo(0, h);
                        ctx.closePath();
                        ctx.fill();

                        // Arcs additifs bg pour lisser la jonction menu/barre/bordures.
                        // Haut-droit : raccord entre le haut du menu et la barre.
                        ctx.beginPath();
                        ctx.moveTo(w, 5);
                        ctx.lineTo(w + cr, 5);
                        ctx.arc(w + cr, cr+5, cr, -Math.PI / 2, Math.PI, true);
                        ctx.lineTo(w, 5);
                        ctx.closePath();
                        ctx.fill();

                        // Bas-gauche : raccord entre le bas du menu et la bordure gauche.
                        ctx.beginPath();
                        ctx.moveTo(frameSize, h);
                        ctx.lineTo(frameSize+cr, h);
                        ctx.arc(frameSize+cr, h+cr, cr, -Math.PI / 2, Math.PI, true);
                        ctx.lineTo(frameSize, h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                ColumnLayout {
                    width: menuCard.menuWidth - 48
                    height: menuCard.contentHeight - 48
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 24
                    anchors.topMargin: 24
                    spacing: 10

                    Text {
                        text: "quick actions"
                        color: muted
                        font.pixelSize: 26
                        font.bold: true
                        font.family: "Annotation Mono"
                    }

                    Repeater {
                        model: [
                            {
                                label: "Launcher",
                                hint: "Super + Space",
                                command: "rofi -combi-modi window,drun -theme $HOME/.config/rofi/my-rofi/style_12 -show drun"
                            },
                            {
                                label: "Restore minimized",
                                hint: "Alt + M",
                                command: "$HOME/.config/rofi/my-rofi/restore-minimized"
                            },
                            {
                                label: "Power menu",
                                hint: "Super + P",
                                command: "$HOME/.config/rofi/my-rofi/powermenu.sh"
                            },
                            {
                                label: "Spotlight",
                                hint: "Super + Shift + S",
                                command: "$HOME/.config/rofi/my-rofi/spotlight"
                            },
                            {
                                label: "Change Wallpaper",
                                hint: "Super + Alt + R",
                                command: "bspc wm -r"
                            }

                        ]

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            height: 48
                            radius: 18
                            color: actionMouse.containsMouse ? hover : "transparent"
                            border.color: actionMouse.containsMouse ? active : muted
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: modelData.label
                                    color: fg
                                    font.pixelSize: 22
                                    font.bold: true
                                    font.family: "Annotation Mono"
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: modelData.hint
                                    color: muted
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: runMenuCommand(modelData.command)
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            menuCloseTimer.stop();
                            menuOpen = true;
                        } else {
                            menuCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Menu audio qui sort par la droite : volume simple puis périphériques au hover.
    PanelWindow {
        anchors {
            top: true
            right: true
        }

        margins {
            top: 0
            right: 0
        }

        implicitWidth: 420 + cornerRadius
        implicitHeight: 540
        color: "transparent"
        mask: Region { item: volumeCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: volumeCard
                width: 420 + cornerRadius
                height: (audioDetailsOpen ? 500 : 250) + cornerRadius
                readonly property int contentWidth: 420
                readonly property int contentHeight: audioDetailsOpen ? 500 : 250
                readonly property int bodyX: cornerRadius
                readonly property int volumeRadius: 24
                readonly property int concaveRadius: cornerRadius
                x: 0
                y: volumeMenuOpen ? 0 : -parent.height

                Canvas {
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = volumeCard.volumeRadius;
                        const cr = volumeCard.concaveRadius;
                        const x0 = volumeCard.bodyX;
                        const w = volumeCard.contentWidth;
                        const h = volumeCard.contentHeight;
                        const right = x0 + w;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Corps principal : son bord droit est à `right`, donc collé
                        // au bord droit de la fenêtre/panel. Bas-gauche arrondi externe.
                        ctx.beginPath();
                        ctx.moveTo(x0, 0);
                        ctx.lineTo(right, 0);
                        ctx.lineTo(right, h);
                        ctx.lineTo(x0 + r, h);
                        ctx.quadraticCurveTo(x0, h, x0, h - r);
                        ctx.lineTo(x0, 0);
                        ctx.closePath();
                        ctx.fill();

                        // Raccord additif haut-gauche : même principe que le dock,
                        // on ajoute du bg pour faire une jonction smooth avec la barre.
                        ctx.beginPath();
                        ctx.moveTo(x0, 0);
                        ctx.lineTo(0, 0);
                        ctx.arc(0, cr, cr, -Math.PI / 2, 0, false);
                        ctx.lineTo(x0, 0);
                        ctx.closePath();
                        ctx.fill();

                        // Raccord additif bas-droit vers la bordure droite.
                        ctx.beginPath();
                        ctx.moveTo(right - frameSize, h);
                        ctx.lineTo(right - frameSize - cr, h);
                        ctx.arc(right - frameSize - cr, h + cr, cr, -Math.PI / 2, 0, false);
                        ctx.lineTo(right - frameSize, h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Behavior on y {
                    NumberAnimation { duration: 400; easing.type: volumeMenuOpen ? Easing.OutCubic : Easing.InCubic }
                }

                Behavior on height {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    width: volumeCard.contentWidth - 40
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: volumeCard.bodyX + 20
                    anchors.topMargin: 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "volume"
                                color: muted
                                font.pixelSize: 24
                                font.bold: true
                                font.family: "Annotation Mono"
                            }

                            Text {
                                text: audioInfo.sinkVolume + "%"
                                color: fg
                                font.pixelSize: 32
                                font.bold: true
                                font.family: "Annotation Mono"
                            }
                        }

                        Rectangle {
                            width: 52
                            height: 52
                            radius: 18
                            color: muteMouse.containsMouse ? hover : "transparent"
                            border.color: muted
                            border.width: 0

                            Text {
                                anchors.centerIn: parent
                                text: audioInfo.sinkMuted ? "󰸈" : "󰕾"
                                color: fg
                                font.pixelSize: 28
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: runAudioCommand("pactl set-sink-mute @DEFAULT_SINK@ toggle")
                            }
                        }
                    }

                    Rectangle {
                        id: volumeSlider
                        Layout.fillWidth: true
                        height: 46
                        radius: 18
                        color: "transparent"
                        border.color: muted
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            width: parent.width - 28
                            height: 8
                            radius: 4
                            color: muted
                            opacity: 0.35
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            width: Math.max(8, (parent.width - 28) * Math.min(100, audioInfo.sinkVolume) / 100)
                            height: 8
                            radius: 4
                            color: active
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: fg
                            border.color: active
                            border.width: 2
                            x: 14 + (parent.width - 28) * Math.min(100, audioInfo.sinkVolume) / 100 - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function setVolumeFromX(px) {
                                const usable = width - 28;
                                const ratio = Math.max(0, Math.min(1, (px - 14) / usable));
                                const value = Math.round(ratio * 100);
                                runAudioCommand("pactl set-sink-volume @DEFAULT_SINK@ " + value + "%");
                            }

                            onPressed: function(mouse) { setVolumeFromX(mouse.x); }
                            onPositionChanged: function(mouse) {
                                if (pressed)
                                    setVolumeFromX(mouse.x);
                            }
                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0)
                                    runAudioCommand("pactl set-sink-volume @DEFAULT_SINK@ +5%");
                                else
                                    runAudioCommand("pactl set-sink-volume @DEFAULT_SINK@ -5%");
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 16
                        color: audioDetailsOpen ? hover : "transparent"
                        border.color: muted
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: "audio sources"
                                color: fg
                                font.pixelSize: 24
                                font.bold: true
                                font.family: "Annotation Mono"
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: audioDetailsOpen ? "󰅀" : "󰅂"
                                color: muted
                                font.pixelSize: 26
                                font.family: "Annotation Mono"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: audioDetailsOpen = true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: audioDetailsOpen
                        opacity: audioDetailsOpen ? 1 : 0
                        spacing: 8

                        Text {
                            text: "outputs"
                            color: active
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Annotation Mono"
                        }

                        Repeater {
                            model: audioInfo.sinks

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 38
                                radius: 12
                                color: sinkMouse.containsMouse || modelData.default ? hover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text { text: modelData.default ? "●" : "○"; color: modelData.default ? active : muted; font.pixelSize: 13 }
                                    Text { Layout.fillWidth: true; text: modelData.description; color: fg; font.pixelSize: 18; elide: Text.ElideRight; font.family: "Annotation Mono"}
                                    Text { text: modelData.volume + "%"; color: muted; font.pixelSize: 18; font.family: "Annotation Mono"}
                                }

                                MouseArea {
                                    id: sinkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: runAudioCommand("pactl set-default-sink " + modelData.name)
                                }
                            }
                        }

                        Text {
                            text: "inputs"
                            color: active
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Annotation Mono"
                        }

                        Repeater {
                            model: audioInfo.sources

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 38
                                radius: 12
                                color: sourceMouse.containsMouse || modelData.default ? hover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text { text: modelData.default ? "●" : "○"; color: modelData.default ? active : muted; font.pixelSize: 13 }
                                    Text { Layout.fillWidth: true; text: modelData.description; color: fg; font.pixelSize: 18; elide: Text.ElideRight; font.family: "Annotation Mono"}
                                    Text { text: modelData.volume + "%"; color: muted; font.pixelSize: 18; font.family: "Annotation Mono"}
                                }

                                MouseArea {
                                    id: sourceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: runAudioCommand("pactl set-default-source " + modelData.name)
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            volumeCloseTimer.stop();
                            volumeMenuOpen = true;
                            refreshAudio();
                        } else {
                            volumeCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Bord gauche du cadre.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
        }

        implicitWidth: frameSize
        color: bg

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: frameSize
            height: 360
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    sideDockCloseTimer.stop();
                    sideDockOpen = true;
                    refreshSideInfo();
                }
            }
        }
    }

    // Side dock infos système : sort du milieu du bord gauche.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
        }

        implicitWidth: 154
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: sideDockCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: sideDockCard
                width: 120 + cornerRadius
                height: 520 + 2 * cornerRadius
                readonly property int bodyWidth: 120
                readonly property int bodyHeight: 520
                readonly property int bodyY: cornerRadius
                readonly property int sideRadius: 34
                readonly property int concaveRadius: cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                x: sideDockOpen ? frameSize : -width - 8

                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = sideDockCard.sideRadius;
                        const cr = sideDockCard.concaveRadius;
                        const w = sideDockCard.bodyWidth;
                        const y0 = sideDockCard.bodyY;
                        const h = sideDockCard.bodyHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Côté gauche droit/collé à la bordure, côté droit arrondi.
                        ctx.beginPath();
                        ctx.moveTo(0, y0);
                        ctx.lineTo(w - r, y0);
                        ctx.quadraticCurveTo(w, y0, w, y0 + r);
                        ctx.lineTo(w, y0 + h - r);
                        ctx.quadraticCurveTo(w, y0 + h, w - r, y0 + h);
                        ctx.lineTo(0, y0 + h);
                        ctx.lineTo(0, y0);
                        ctx.closePath();
                        ctx.fill();

                        // Raccords additifs à gauche vers la bordure.
                        ctx.beginPath();
                        ctx.moveTo(0, y0);
                        ctx.lineTo(cr, y0);
                        ctx.quadraticCurveTo(0, y0, 0, y0 - 1.5 * cr);
                        ctx.lineTo(0, y0);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(0, y0 + h);
                        ctx.lineTo(cr, y0 + h);
                        ctx.quadraticCurveTo(0, y0 + h, 0, y0 + h + 1.5 * cr);
                        ctx.lineTo(0, y0 + h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Behavior on x {
                    NumberAnimation { duration: 400; easing.type: sideDockOpen ? Easing.OutCubic : Easing.InCubic }
                }

                ColumnLayout {
                    width: sideDockCard.bodyWidth - 18
                    height: sideDockCard.bodyHeight - 24
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 9
                    anchors.topMargin: sideDockCard.bodyY + 12
                    spacing: 7

                    Repeater {
                        model: [
                            { kind: "wifi", icon: "󰖩", label: "wifi" },
                            { kind: "bluetooth", icon: "󰂯", label: "bt" },
                            { kind: "ram", icon: "", label: "ram" },
                            { kind: "disk", icon: "󰋊", label: "disk" },
                            { kind: "cpu", icon: "", label: "cpu" },
                            { kind: "gpu", icon: "󰢮", label: "gpu" },
                            { kind: "temp", icon: "", label: "temp" }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 64
                            radius: 16
                            color: sideItemHover.hovered || sideMenuType === modelData.kind ? hover : bg
                            border.color: sideItemHover.hovered || sideMenuType === modelData.kind ? active : muted
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: modelData.icon
                                    color: fg
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: muted
                                        font.pixelSize: 10
                                        font.family: "Annotation Mono"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: sideMetricValue(modelData.kind)
                                        color: fg
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Annotation Mono"
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            HoverHandler {
                                id: sideItemHover
                                onHoveredChanged: {
                                    if (hovered) {
                                        sideDockCloseTimer.stop();
                                        sideDockOpen = true;
                                        refreshSideInfo();
                                        if (modelData.kind === "wifi" || modelData.kind === "bluetooth")
                                            sideMenuType = modelData.kind;
                                    } else if (modelData.kind !== sideMenuType) {
                                        sideDockCloseTimer.restart();
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.kind === "bluetooth")
                                        runSideCommand("bluetoothctl power " + (sideInfo.bluetooth.powered ? "off" : "on"));
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            sideDockCloseTimer.stop();
                            sideDockOpen = true;
                        } else {
                            sideDockCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Menus hover du side dock : wifi / bluetooth.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
        }

        implicitWidth: sideDockCard.bodyWidth + frameSize + 330 + cornerRadius
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: sideMenuCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: sideMenuCard
                width: 330 + cornerRadius
                height: (sideMenuType === "wifi" ? 415 : 325) + 2 * cornerRadius
                readonly property int bodyWidth: 330
                readonly property int bodyHeight: sideMenuType === "wifi" ? 415 : 325
                readonly property int bodyY: cornerRadius
                readonly property int menuRadius: 24
                readonly property int concaveRadius: cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                x: sideMenuType.length > 0 ? sideDockCard.bodyWidth + frameSize : -width

                Behavior on x {
                    NumberAnimation { duration: 400; easing.type: sideMenuType.length > 0 ? Easing.OutCubic : Easing.InCubic }
                }

                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = sideMenuCard.menuRadius;
                        const cr = sideMenuCard.concaveRadius;
                        const w = sideMenuCard.bodyWidth;
                        const y0 = sideMenuCard.bodyY;
                        const h = sideMenuCard.bodyHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Même logique que le dock gauche : gauche connecté,
                        // droite arrondie, raccords concaves/additifs côté gauche.
                        ctx.beginPath();
                        ctx.moveTo(0, y0);
                        ctx.lineTo(w - r, y0);
                        ctx.quadraticCurveTo(w, y0, w, y0 + r);
                        ctx.lineTo(w, y0 + h - r);
                        ctx.quadraticCurveTo(w, y0 + h, w - r, y0 + h);
                        ctx.lineTo(0, y0 + h);
                        ctx.lineTo(0, y0);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(0, y0);
                        ctx.lineTo(cr, y0);
                        ctx.quadraticCurveTo(0, y0, 0, y0 - 1.5 * cr);
                        ctx.lineTo(0, y0);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(0, y0 + h);
                        ctx.lineTo(cr, y0 + h);
                        ctx.quadraticCurveTo(0, y0 + h, 0, y0 + h + 1.5 * cr);
                        ctx.lineTo(0, y0 + h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                ColumnLayout {
                    width: sideMenuCard.bodyWidth - 36
                    height: sideMenuCard.bodyHeight - 36
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 18
                    anchors.topMargin: sideMenuCard.bodyY + 18
                    spacing: 7

                    Text {
                        text: sideMenuType === "wifi" ? "wifi networks" : "bluetooth devices"
                        color: fg
                        font.pixelSize: 20
                        font.bold: true
                        font.family: "Annotation Mono"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: sideMenuType === "wifi"
                              ? (sideInfo.wifi.current.connected ? "connected: " + sideInfo.wifi.current.ssid + " · " + sideInfo.wifi.current.signal + "%" : "not connected")
                              : (sideInfo.bluetooth.powered ? "powered on" : "powered off")
                        color: muted
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        font.family: "Annotation Mono"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 13
                        color: "transparent"
                        border.color: muted
                        border.width: 1
                        visible: sideMenuType === "wifi"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search wifi"
                            color: muted
                            opacity: wifiSearch.length === 0 && !wifiSearchInput.activeFocus ? 0.75 : 0
                            font.pixelSize: 13
                            font.family: "Annotation Mono"
                        }

                        TextInput {
                            id: wifiSearchInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: wifiSearch
                            color: fg
                            selectionColor: active
                            selectedTextColor: bg
                            font.pixelSize: 13
                            font.family: "Annotation Mono"
                            clip: true
                            onTextChanged: wifiSearch = text
                            onActiveFocusChanged: {
                                if (activeFocus)
                                    refreshSideInfo();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 13
                        color: sideToggleMouse.containsMouse ? hover : "transparent"
                        border.color: muted
                        border.width: 1
                        visible: sideMenuType === "bluetooth"

                        Text {
                            anchors.centerIn: parent
                            text: sideInfo.bluetooth.powered ? "turn bluetooth off" : "turn bluetooth on"
                            color: fg
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Annotation Mono"
                        }

                        MouseArea {
                            id: sideToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: runSideCommand("bluetoothctl power " + (sideInfo.bluetooth.powered ? "off" : "on"))
                        }
                    }

                    Repeater {
                        model: sideMenuType === "wifi" ? filteredWifiNetworks() : sideInfo.bluetooth.devices

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 34
                            radius: 11
                            color: sideMenuItemMouse.containsMouse || modelData.active || modelData.connected ? hover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: modelData.active || modelData.connected ? "●" : "○"
                                    color: modelData.active || modelData.connected ? active : muted
                                    font.pixelSize: 12
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: sideMenuType === "wifi" ? modelData.ssid : modelData.name
                                    color: fg
                                    font.pixelSize: 12
                                    font.family: "Annotation Mono"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: sideMenuType === "wifi"
                                          ? ((modelData.locked ? " " : "") + modelData.signal + "%")
                                          : ""
                                    color: muted
                                    font.pixelSize: 11
                                    font.family: "Annotation Mono"
                                }
                            }

                            MouseArea {
                                id: sideMenuItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (sideMenuType === "wifi") {
                                        if (!modelData.active)
                                            runSideCommand("/home/arnaud/.config/quickshell/scripts/wifi-connect.sh " + shellQuote(modelData.ssid));
                                    } else {
                                        runSideCommand("bluetoothctl connect " + modelData.mac);
                                    }
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            sideDockCloseTimer.stop();
                            sideDockOpen = true;
                        } else {
                            sideDockCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Bord droit du cadre.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            right: true
        }

        implicitWidth: frameSize
        color: bg

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: frameSize
            height: 190
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    powerDockCloseTimer.stop();
                    powerDockOpen = true;
                }
            }
        }
    }

    // Power dock latéral : sort du milieu du bord droit.
    PanelWindow {
        anchors {
            top: true
            bottom: true
            right: true
        }

        implicitWidth: 172
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: powerDockCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: powerDockCard
                width: 172 - frameSize
                height: 480 + 2 * cornerRadius
                readonly property int bodyWidth: 172 - frameSize
                readonly property int bodyHeight: 480
                readonly property int bodyY: cornerRadius
                readonly property int powerRadius: 34
                readonly property int concaveRadius: cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                x: powerDockOpen ? 0 : parent.width

                Canvas {
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = powerDockCard.powerRadius;
                        const cr = powerDockCard.concaveRadius;
                        const w = powerDockCard.bodyWidth;
                        const y0 = powerDockCard.bodyY;
                        const h = powerDockCard.bodyHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Corps : côté gauche arrondi, côté droit droit pour se coller
                        // au raccord vers la bordure droite.
                        ctx.beginPath();
                        ctx.moveTo(w, y0);
                        ctx.lineTo(w, y0 + h);
                        ctx.lineTo(r, y0 + h);
                        ctx.quadraticCurveTo(0, y0 + h, 0, y0 + h - r);
                        ctx.lineTo(0, y0 + r);
                        ctx.quadraticCurveTo(0, y0, r, y0);
                        ctx.lineTo(w, y0);
                        ctx.closePath();
                        ctx.fill();

                        // Raccords additifs à droite, inspirés du dock du bas :
                        // ça prolonge le bg pour une transition smooth avec la bordure.
                        ctx.beginPath();
                        ctx.moveTo(w, y0);
                        ctx.lineTo(w - cr, y0);
                        ctx.quadraticCurveTo(w, y0, w, y0 - 1.5 * cr);
                        ctx.lineTo(w, y0);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(w, y0 + h);
                        ctx.lineTo(w - cr, y0 + h);
                        ctx.quadraticCurveTo(w, y0 + h, w, y0 + h + 1.5 * cr);
                        ctx.lineTo(w, y0 + h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 400
                        easing.type: powerDockOpen ? Easing.OutCubic : Easing.InCubic
                    }
                }

                ColumnLayout {
                    width: powerDockCard.bodyWidth - 24
                    height: powerDockCard.bodyHeight - 24
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.topMargin: powerDockCard.bodyY + 12
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "⏻", label: "off", command: "/home/arnaud/.config/quickshell/scripts/power-action.sh poweroff" },
                            { icon: "⟲", label: "reboot", command: "/home/arnaud/.config/quickshell/scripts/power-action.sh reboot" },
                            { icon: "⏾", label: "lock", command: "/home/arnaud/.config/quickshell/scripts/power-action.sh lock" },
                            { icon: "□", label: "sleep", command: "/home/arnaud/.config/quickshell/scripts/power-action.sh suspend" }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 86
                            radius: 18
                            color: powerItemHover.hovered ? hover : bg
                            border.color: powerItemHover.hovered ? active : muted
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: fg
                                    font.pixelSize: 34
                                    font.bold: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: muted
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Andy"
                                }
                            }

                            HoverHandler { id: powerItemHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: runPowerCommand(modelData.command)
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            powerDockCloseTimer.stop();
                            powerDockOpen = true;
                        } else {
                            powerDockCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Bord bas du cadre.
    PanelWindow {
        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: frameSize
        color: bg

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            height: frameSize
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    dockCloseTimer.stop();
                    dockOpen = true;
                }
            }
        }
    }

    // Dock d'apps qui sort du bas quand on survole le centre de la bordure.
    PanelWindow {
        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: 140
        color: "transparent"
        mask: Region { item: dockCard }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: dockCard
                width: 700 + 2 * cornerRadius
                height: 120
                readonly property int dockWidth: 700
                readonly property int dockHeight: 120
                readonly property int dockRadius: 48
                readonly property int concaveRadius: cornerRadius
                x: (parent.width - width) / 2 + 2*cornerRadius
                y: dockOpen ? 20 : parent.height

                Canvas {
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const r = dockCard.dockRadius;
                        const cr = dockCard.concaveRadius;
                        const x0 = cr;
                        const w = dockCard.dockWidth;
                        const h = dockCard.dockHeight;

                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = bg;

                        // Corps du dock : coins hauts arrondis, bas droit/gauche droits
                        // pour se fondre dans la bordure inférieure.
                        ctx.beginPath();
                        ctx.moveTo(x0, h);
                        ctx.lineTo(x0, r);
                        ctx.quadraticCurveTo(x0, 0, x0 + r, 0);
                        ctx.lineTo(x0 + w - r, 0);
                        ctx.quadraticCurveTo(x0 + w, 0, x0 + w, r);
                        ctx.lineTo(x0 + w, h);
                        ctx.closePath();
                        ctx.fill();

                        // Arcs additifs bg pour raccorder le bas du dock à la bordure.
                        ctx.beginPath();
                        ctx.moveTo(x0, h);
                        ctx.lineTo(x0 - cr, h);
                        ctx.quadraticCurveTo(x0, h, x0, h - 1.5*cr);
                        // ctx.arc(x0 - cr, h - cr, cr, Math.PI / 2, 0, true);
                        ctx.lineTo(x0, h);
                        ctx.closePath();
                        ctx.fill();

                        ctx.beginPath();
                        ctx.moveTo(x0 + w, h);
                        ctx.lineTo(x0 + w + cr, h);
                        ctx.quadraticCurveTo(x0 + w, h, x0 + w, h - 1.5*cr);
                        // ctx.arc(x0 + w + cr, h - cr, cr, Math.PI / 2, Math.PI, false);
                        ctx.lineTo(x0 + w, h);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 400
                        easing.type: dockOpen ? Easing.OutCubic : Easing.InCubic
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 28

                    Repeater {
                        model: [
                            { icon: "󰈹", label: "Zen", command: "zen-browser &" },
                            { icon: "", label: "Kitty", command: "kitty --working-directory=$HOME/Desktop &" },
                            { icon: "󰂺", label: "Zotero", command: "zotero &" },
                            { icon: "", label: "Nemo", command: "nemo &" }
                        ]

                        Item {
                            required property var modelData

                            width: 100
                            height: 100

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: dockItemHover.hovered ? hover : bg
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: fg
                                font.pixelSize: 50
                                font.bold: true
                            }

                            HoverHandler {
                                id: dockItemHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: runDockCommand(modelData.command)
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            dockCloseTimer.stop();
                            dockOpen = true;
                        } else {
                            dockCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Coins intérieurs concaves : chaque petit carré est bg, puis on y
    // "creuse" un quart de cercle transparent côté zone centrale.
    PanelWindow {
        anchors {
            top: true
            left: true
        }

        margins {
            top: 0
            left: 0
        }

        implicitWidth: cornerRadius
        implicitHeight: cornerRadius
        color: "transparent"

        Canvas {
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = bg;
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(width, height, cornerRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }

    PanelWindow {
        anchors {
            top: true
            right: true
        }

        margins {
            top: 0
            right: 0
        }

        implicitWidth: cornerRadius
        implicitHeight: cornerRadius
        color: "transparent"

        Canvas {
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = bg;
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(0, height, cornerRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }

    PanelWindow {
        anchors {
            bottom: true
            left: true
        }

        margins {
            bottom: -140
            left: 0
        }

        implicitWidth: cornerRadius
        implicitHeight: cornerRadius
        color: "transparent"

        Canvas {
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = bg;
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(width, 0, cornerRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }

    PanelWindow {
        anchors {
            bottom: true
            right: true
        }

        margins {
            bottom: -140
            right: 0
        }

        implicitWidth: cornerRadius
        implicitHeight: cornerRadius
        color: "transparent"

        Canvas {
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = bg;
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(0, 0, cornerRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }
}
