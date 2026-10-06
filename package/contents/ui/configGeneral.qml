import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Ligados automaticamente às entradas de config/main.xml
    property string cfg_eventsJson
    property string cfg_eventsJsonDefault: "[]"
    property alias cfg_warnDays: warnSpin.value
    property int cfg_warnDaysDefault: 7
    property alias cfg_hidePast: hidePastCheck.checked
    property bool cfg_hidePastDefault: true
    property alias cfg_compactShowName: compactNameCheck.checked
    property bool cfg_compactShowNameDefault: true

    // Evita recarregar o modelo quando fomos nós que escrevemos o JSON
    property bool committing: false

    ListModel {
        id: eventsModel
    }

    function isoToBr(iso) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
        return m ? m[3] + "/" + m[2] + "/" + m[1] : "";
    }

    function brToIso(br) {
        const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec((br || "").trim());
        if (!m) {
            return "";
        }
        const day = Number(m[1]), month = Number(m[2]), year = Number(m[3]);
        const d = new Date(year, month - 1, day);
        // Rejeita datas como 31/02 que o Date "corrige" silenciosamente
        if (d.getFullYear() !== year || d.getMonth() !== month - 1 || d.getDate() !== day) {
            return "";
        }
        return m[3] + "-" + m[2] + "-" + m[1];
    }

    function daysUntil(iso) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
        if (!m) {
            return null;
        }
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const target = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
        return Math.round((target - today) / 86400000);
    }

    function statusFor(br) {
        if (!(br || "").replace(/[\/\s]/g, "")) {
            return "";
        }
        const iso = brToIso(br);
        if (!iso) {
            return "data inválida";
        }
        const d = daysUntil(iso);
        if (d < 0) {
            return "já passou";
        }
        if (d === 0) {
            return "é hoje";
        }
        if (d === 1) {
            return "falta 1 dia";
        }
        return "faltam " + d + " dias";
    }

    function load() {
        eventsModel.clear();
        let arr = [];
        try {
            arr = JSON.parse(cfg_eventsJson || "[]");
        } catch (e) {
            arr = [];
        }
        for (let i = 0; i < arr.length; ++i) {
            eventsModel.append({
                name: String(arr[i].name || ""),
                dateBr: isoToBr(arr[i].date)
            });
        }
    }

    function commit() {
        const arr = [];
        for (let i = 0; i < eventsModel.count; ++i) {
            const e = eventsModel.get(i);
            const iso = brToIso(e.dateBr);
            if (!iso || !e.name.trim()) {
                continue; // linhas incompletas ficam só na UI
            }
            arr.push({ name: e.name.trim(), date: iso });
        }
        committing = true;
        cfg_eventsJson = JSON.stringify(arr);
        committing = false;
    }

    onCfg_eventsJsonChanged: {
        if (!committing) {
            load();
        }
    }

    Component.onCompleted: load()

    ColumnLayout {
        width: parent ? parent.width : implicitWidth
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: "Cadastre as suas provas e compromissos. A data usa o formato DD/MM/AAAA."
            wrapMode: Text.WordWrap
            opacity: 0.8
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: eventsModel

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: model.name
                        placeholderText: "Nome (ex.: Prova de Cálculo)"
                        onTextEdited: {
                            eventsModel.setProperty(index, "name", text);
                            page.commit();
                        }
                    }

                    QQC2.TextField {
                        id: dateField
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        text: model.dateBr
                        inputMask: "00/00/0000"
                        placeholderText: "DD/MM/AAAA"
                        onTextEdited: {
                            eventsModel.setProperty(index, "dateBr", text);
                            page.commit();
                        }
                    }

                    QQC2.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        text: page.statusFor(model.dateBr)
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.75
                        color: text === "data inválida"
                            ? Kirigami.Theme.negativeTextColor
                            : Kirigami.Theme.textColor
                    }

                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: "Remover"
                        QQC2.ToolTip.visible: hovered
                        onClicked: {
                            eventsModel.remove(index);
                            page.commit();
                        }
                    }
                }
            }

            QQC2.Button {
                text: "Adicionar compromisso"
                icon.name: "list-add"
                onClicked: eventsModel.append({ name: "", dateBr: "" })
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.SpinBox {
                id: warnSpin
                Kirigami.FormData.label: "Alertar (vermelho) a partir de:"
                from: 0
                to: 365
                textFromValue: (value) => value === 1 ? "1 dia" : value + " dias"
                valueFromText: (text) => parseInt(text) || 0
            }

            QQC2.CheckBox {
                id: hidePastCheck
                Kirigami.FormData.label: "Compromissos passados:"
                text: "Ocultar da lista"
            }

            QQC2.CheckBox {
                id: compactNameCheck
                Kirigami.FormData.label: "No painel:"
                text: "Mostrar o nome junto da contagem"
            }
        }
    }
}
