/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Replacement for org.kde.plasma.activitybar. The stock applet is built on
    PlasmaComponents.TabBar, whose own currentIndex fights the "current" role
    of the model: the highlight drifts away from the real activity and clicks
    on the drifted tab do nothing. Here every tab is a plain MouseArea and the
    highlight is derived only from the model.

    With the kwin-activity-slide effect, the highlight follows the slide while
    the fingers drag the next activity in.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.activities as Activities
import org.kde.plasma.activityswitcher as ActivitySwitcher
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.config as KConfig
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // The indicator sits on the edge that faces the screen, like the stock applet.
    readonly property bool indicatorOnTop: Plasmoid.location === PlasmaCore.Types.BottomEdge
                                        || Plasmoid.location === PlasmaCore.Types.Floating

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.minimumWidth: vertical ? -1 : tabs.implicitWidth
    Layout.preferredWidth: vertical ? -1 : tabs.implicitWidth
    Layout.minimumHeight: vertical ? tabs.implicitHeight : -1
    Layout.preferredHeight: vertical ? tabs.implicitHeight : -1

    Activities.ActivityModel {
        id: activityModel
    }

    // Published by the kwin-activity-slide effect; empty when it isn't loaded.
    DBus.Properties {
        id: slide
        busType: DBus.BusType.Session
        service: "org.kde.KWin"
        path: "/ActivitySlide"
        iface: "io.github.doctorutsugi.ActivitySlide"
    }

    // During a swipe the effect draws this bar itself, in step with the fingers;
    // a bar drawn here would always be a frame or two behind.
    readonly property bool effectDrawsBar: slide.properties.drawsIndicator === true
                                        && slide.properties.active === true
                                        && slide.properties.gesture === true

    // Hands the effect the geometry of the bar for every tab, in the panel window's coordinates.
    function sendIndicator() {
        const tabRects = {};
        for (let i = 0; i < tabRepeater.count; ++i) {
            const tab = tabRepeater.itemAt(i);
            if (tab) {
                const p = tab.mapToItem(null, 0, 0);
                tabRects[tab.model.id] = [p.x, p.y, tab.width, tab.height];
            }
        }
        const json = JSON.stringify({
            window: [root.Window.width, root.Window.height],
            tabs: tabRects,
            thickness: indicator.height,
            color: String(Kirigami.Theme.highlightColor),
            onTop: root.indicatorOnTop,
        });
        if (json === lastIndicator) {
            return;
        }
        lastIndicator = json;
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/ActivitySlide",
            iface: "io.github.doctorutsugi.ActivitySlide",
            member: "SetIndicator",
            arguments: [json],
        });
    }
    property string lastIndicator: ""

    // Layout changes come in bursts; send once they settle.
    Timer {
        id: indicatorTimer
        interval: 300
        onTriggered: root.sendIndicator()
    }
    onWidthChanged: indicatorTimer.restart()
    onHeightChanged: indicatorTimer.restart()
    onXChanged: indicatorTimer.restart()
    onYChanged: indicatorTimer.restart()
    Window.onWidthChanged: indicatorTimer.restart()
    Window.onHeightChanged: indicatorTimer.restart()
    onHighlightRectChanged: indicatorTimer.restart()
    // KWin restarts drop what the effect knew.
    Connections {
        target: slide
        function onRefreshed() {
            root.lastIndicator = "";
            indicatorTimer.restart();
        }
    }

    function tabFor(activityId) {
        for (let i = 0; i < tabRepeater.count; ++i) {
            const tab = tabRepeater.itemAt(i);
            if (tab && tab.model.id === activityId) {
                return tab;
            }
        }
        return null;
    }

    function currentTab() {
        for (let i = 0; i < tabRepeater.count; ++i) {
            const tab = tabRepeater.itemAt(i);
            if (tab && tab.isCurrent) {
                return tab;
            }
        }
        return null;
    }

    // Rectangle of the tab the highlight sits on, between two tabs while the fingers
    // drag the slide. Switches made otherwise move it straight to the new tab.
    readonly property rect highlightRect: {
        const slideState = slide.properties;
        const from = slideState.active === true && slideState.gesture === true ? tabFor(slideState.from) : null;
        if (from) {
            const to = tabFor(slideState.to);
            const p = slideState.progress ?? 0;
            if (to) {
                return Qt.rect(from.x + (to.x - from.x) * p, from.y + (to.y - from.y) * p,
                               from.width + (to.width - from.width) * p, from.height + (to.height - from.height) * p);
            }
            // No activity on that side: the highlight only gives a little, like the desktop.
            const shift = (slideState.direction ?? 1) * p;
            return Qt.rect(from.x + (root.vertical ? 0 : shift * from.width), from.y + (root.vertical ? shift * from.height : 0),
                           from.width, from.height);
        }
        const current = currentTab();
        return current ? Qt.rect(current.x, current.y, current.width, current.height) : Qt.rect(0, 0, 0, 0);
    }

    GridLayout {
        id: tabs

        anchors.fill: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            id: tabRepeater
            model: activityModel

            delegate: MouseArea {
                id: tab

                required property var model

                readonly property bool isCurrent: model.current === true
                // Activities with an icon show it instead of their name, which moves to a tooltip.
                readonly property bool showIcon: (model.icon ?? "") !== ""
                readonly property Item content: showIcon ? icon : label

                Layout.fillWidth: root.vertical
                Layout.fillHeight: !root.vertical
                implicitWidth: content.implicitWidth + Kirigami.Units.largeSpacing * 2
                implicitHeight: content.implicitHeight + Kirigami.Units.smallSpacing * 2

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: model.name
                Accessible.description: i18n("Switch to activity %1", model.name)
                Accessible.checked: isCurrent

                onClicked: activityModel.setCurrentActivity(model.id, function () {})
                Keys.onPressed: event => {
                    if ([Qt.Key_Space, Qt.Key_Enter, Qt.Key_Return, Qt.Key_Select].includes(event.key)) {
                        activityModel.setCurrentActivity(tab.model.id, function () {});
                        event.accepted = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Kirigami.Theme.highlightColor
                    opacity: tab.containsPress ? 0.3 : (tab.containsMouse || tab.activeFocus ? 0.15 : 0)
                    radius: Kirigami.Units.cornerRadius
                }

                Kirigami.Icon {
                    id: icon
                    anchors.centerIn: parent
                    visible: tab.showIcon
                    source: tab.model.icon ?? ""
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    width: implicitWidth
                    height: implicitHeight
                    opacity: tab.isCurrent ? 1 : 0.5
                }

                PlasmaComponents.ToolTip {
                    text: tab.model.name
                    visible: tab.showIcon && tab.containsMouse
                }

                PlasmaComponents.Label {
                    id: label
                    anchors.centerIn: parent
                    visible: !tab.showIcon
                    text: tab.model.name
                    font.bold: false
                    color: tab.isCurrent ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        id: indicator
        visible: root.highlightRect.width > 0 && !root.effectDrawsBar
        color: Kirigami.Theme.highlightColor
        x: tabs.x + root.highlightRect.x
        y: tabs.y + (root.indicatorOnTop ? root.highlightRect.y : root.highlightRect.y + root.highlightRect.height - height)
        width: root.highlightRect.width
        height: Math.round(Kirigami.Units.smallSpacing / 2) * 2 || 2
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Show Activity Manager")
            icon.name: "activities"
            onTriggered: ActivitySwitcher.Backend.toggleActivityManager()
        }
    ]

    PlasmaCore.Action {
        id: configureAction
        text: i18nc("@action:inmenu", "&Configure Activities…")
        icon.name: "configure"
        visible: KConfig.KAuthorized.authorizeControlModule("kcm_activities")
        onTriggered: KCMUtils.KCMLauncher.openSystemSettings("kcm_activities")
    }

    Component.onCompleted: Plasmoid.setInternalAction("configure", configureAction)
}
