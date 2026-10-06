import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Lista já filtrada e ordenada: [{ name, date, days }]
    property var events: []
    property var upcoming: null

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation
        : compactRepresentation

    function daysUntil(iso) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
        if (!m) {
            return null;
        }
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const target = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
        if (isNaN(target.getTime())) {
            return null;
        }
        return Math.round((target - today) / 86400000);
    }

    function reload() {
        let raw = [];
        try {
            raw = JSON.parse(Plasmoid.configuration.eventsJson || "[]");
        } catch (e) {
            raw = [];
        }

        const hidePast = Plasmoid.configuration.hidePast;
        const out = [];
        for (let i = 0; i < raw.length; ++i) {
            const days = daysUntil(raw[i].date);
            if (days === null || (hidePast && days < 0)) {
                continue;
            }
            out.push({
                name: (raw[i].name || "").trim() || "Sem nome",
                date: raw[i].date,
                days: days
            });
        }
        out.sort((a, b) => a.days - b.days);

        let next = null;
        for (let j = 0; j < out.length; ++j) {
            if (out[j].days >= 0) {
                next = out[j];
                break;
            }
        }

        events = out;
        upcoming = next;
        scheduleTick();
    }

    // Acorda na próxima meia-noite (no máximo a cada 10 min, para
    // sobreviver a suspend/resume sem gastar CPU).
    function scheduleTick() {
        const now = new Date();
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5);
        tick.interval = Math.max(1000, Math.min(midnight - now, 600000));
        tick.restart();
    }

    Timer {
        id: tick
        repeat: false
        onTriggered: root.reload()
    }

    Connections {
        target: Plasmoid.configuration
        function onEventsJsonChanged() { root.reload(); }
        function onHidePastChanged() { root.reload(); }
    }

    Component.onCompleted: reload()

    function phrase(days) {
        if (days < 0) {
            return days === -1 ? "foi ontem" : "foi há " + (-days) + " dias";
        }
        if (days === 0) {
            return "é hoje";
        }
        if (days === 1) {
            return "falta 1 dia";
        }
        return "faltam " + days + " dias";
    }

    function shortDays(days) {
        if (days === 0) {
            return "hoje";
        }
        if (days === 1) {
            return "amanhã";
        }
        return days + " d";
    }

    function brDate(iso) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
        return m ? m[3] + "/" + m[2] + "/" + m[1] : iso;
    }

    function colorFor(days) {
        if (days < 0) {
            return Kirigami.Theme.disabledTextColor;
        }
        if (days <= Plasmoid.configuration.warnDays) {
            return Kirigami.Theme.negativeTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    toolTipMainText: upcoming ? upcoming.name : "Dias Restantes"
    toolTipSubText: {
        if (events.length === 0) {
            return "Nenhum compromisso cadastrado.\nClique para adicionar.";
        }
        const lines = [];
        for (let i = 0; i < events.length; ++i) {
            lines.push(events[i].name + " — " + phrase(events[i].days) + " (" + brDate(events[i].date) + ")");
        }
        return lines.join("\n");
    }

    compactRepresentation: MouseArea {
        id: compactRoot

        readonly property bool verticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool horizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

        // Num painel vertical não sobra largura para o nome
        readonly property bool showName: Plasmoid.configuration.compactShowName
            && root.upcoming !== null
            && !verticalPanel

        readonly property real maxNameWidth: Kirigami.Units.gridUnit * 6
        readonly property real padding: Kirigami.Units.smallSpacing * 2

        // IMPORTANTE: as dicas de tamanho derivam do implicitWidth dos textos,
        // nunca do implicitWidth do layout. O layout está ancorado ao applet,
        // então medi-lo aqui criaria um ciclo (largura do applet -> largura do
        // layout -> dica de largura do applet) que o Qt quebra silenciosamente,
        // deixando o applet estreito e o texto vazando para fora do painel.
        readonly property real nameWidth: showName
            ? Math.min(compactName.implicitWidth, maxNameWidth) + Kirigami.Units.smallSpacing
            : 0
        readonly property real daysWidth: compactDays.implicitWidth
        readonly property real contentWidth: nameWidth + daysWidth + padding
        readonly property real contentHeight: (showName && verticalPanel
            ? compactName.implicitHeight + compactDays.implicitHeight
            : compactDays.implicitHeight) + padding

        // No painel horizontal a altura vem do painel e a largura do conteúdo;
        // no vertical, o inverso. O mínimo cobre só a contagem, então em painel
        // apertado o nome elide em vez de o widget transbordar.
        Layout.minimumWidth: horizontalPanel ? daysWidth + padding : Kirigami.Units.gridUnit
        Layout.preferredWidth: horizontalPanel ? contentWidth : Kirigami.Units.gridUnit * 3
        Layout.maximumWidth: horizontalPanel ? contentWidth : Number.POSITIVE_INFINITY

        Layout.minimumHeight: verticalPanel ? contentHeight : Kirigami.Units.gridUnit
        Layout.preferredHeight: verticalPanel ? contentHeight : Kirigami.Units.gridUnit * 2
        Layout.maximumHeight: verticalPanel ? contentHeight : Number.POSITIVE_INFINITY

        clip: true

        activeFocusOnTab: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        GridLayout {
            id: compactRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            columns: compactRoot.verticalPanel ? 1 : 2
            rowSpacing: 0
            columnSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                id: compactName
                visible: compactRoot.showName
                text: root.upcoming ? root.upcoming.name : ""
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                // elide só age com largura explícita; fillWidth + minimumWidth 0
                // faz o nome ser o primeiro a ceder quando o painel aperta
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Math.min(implicitWidth, compactRoot.maxNameWidth)
                Layout.maximumWidth: compactRoot.maxNameWidth
                Layout.fillHeight: true
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.85
            }

            PlasmaComponents3.Label {
                id: compactDays
                text: root.upcoming ? root.shortDays(root.upcoming.days) : "—"
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: implicitWidth
                Layout.fillHeight: true
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.Bold
                color: root.upcoming ? root.colorFor(root.upcoming.days) : Kirigami.Theme.textColor
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 11
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
        Layout.preferredHeight: Kirigami.Units.gridUnit * 13

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.upcoming !== null
                text: root.upcoming ? root.upcoming.name : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                font.weight: Font.Bold
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.upcoming !== null
                text: root.upcoming
                    ? (root.upcoming.days === 0 ? "É HOJE"
                        : root.upcoming.days === 1 ? "1 dia"
                        : root.upcoming.days + " dias")
                    : ""
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.6
                font.weight: Font.Bold
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: Kirigami.Theme.smallFont.pointSize
                color: root.upcoming ? root.colorFor(root.upcoming.days) : Kirigami.Theme.textColor
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: root.upcoming !== null
                text: root.upcoming ? root.brDate(root.upcoming.date) : ""
                horizontalAlignment: Text.AlignHCenter
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.events.length === 0
                text: "Nenhum compromisso cadastrado."
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
            }

            PlasmaComponents3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.events.length > 1
                contentWidth: availableWidth

                ListView {
                    model: root.events
                    clip: true
                    spacing: 0

                    delegate: RowLayout {
                        width: ListView.view ? ListView.view.width : 0
                        spacing: Kirigami.Units.smallSpacing
                        opacity: modelData === root.upcoming ? 1.0 : 0.85

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Kirigami.Theme.smallFont.family
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: modelData === root.upcoming ? Font.Bold : Font.Normal
                        }

                        PlasmaComponents3.Label {
                            text: modelData.days < 0 ? "✓" : root.shortDays(modelData.days)
                            font.family: Kirigami.Theme.smallFont.family
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: modelData === root.upcoming ? Font.Bold : Font.Normal
                            color: root.colorFor(modelData.days)
                        }
                    }
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "Editar datas…"
                icon.name: "document-edit"
                onClicked: Plasmoid.internalAction("configure").trigger()
            }
        }
    }
}
