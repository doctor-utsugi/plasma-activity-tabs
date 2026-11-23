# Activity Tabs

A Plasma 6 panel widget that shows your activities as tabs and switches between them on click.

It replaces the stock *Activity Bar* (`org.kde.plasma.activitybar`). That widget is built on
`PlasmaComponents.TabBar`, whose own `currentIndex` fights the `current` role of the activity model.
The highlight drifts away from the real activity, the labels sit off-centre in the panel, and clicking a tab often does nothing.
Here each tab is a plain `MouseArea`, and the highlight comes only from the model.

## Install

```bash
./install.sh
```

Then right-click the panel, choose *Add Widgets…*, and add **Activity Tabs**. You can remove the old *Activity Bar*.

To update after pulling changes, run `./install.sh` again and restart plasmashell:

```bash
systemctl --user restart plasma-plasmashell
```

## Behaviour

- Click, or focus with Tab and press Space/Enter, to switch activity.
- An activity with an icon shows the icon instead of its name.
  Set the icon in System Settings > Activities. Activities without an icon show their name.
- The current activity gets a highlight bar on the edge that faces the screen.
- With [kwin-trackpad-gestures](https://github.com/doctor-utsugi/kwin-trackpad-gestures), the highlight bar
  follows the touchpad swipe: it moves between the tabs as far as the fingers have dragged the next
  activity in, and springs back with it. Other switches move it to the new tab at once.
- The tabs follow the panel orientation (horizontal or vertical).
- The context menu offers *Show Activity Manager* and *Configure Activities…*.

## License

GPL-2.0-or-later, like the Plasma widget it replaces.
