# Segmented Control

A drop-in replacement for UISegmentedControl that mimic iOS 6 AppStore tab
controls.

![The only good piece of UI to extract for this terrible app](https://raw.github.com/rs/SDSegmentedControl/master/Screenshots/screenshot-1.png)
![Images and disabled item](https://raw.github.com/rs/SDSegmentedControl/master/Screenshots/screenshot-2.png)
![While animating/panning with an item of custom width](https://raw.github.com/rs/SDSegmentedControl/master/Screenshots/screenshot-3.png)

## Features:

- Interface Builder support (just throw a UISegmentedControl and change
  its class SDSegmentedControl)
- Animated segment selection, with animated arrow
- Content aware dynamic segment width, also for images
- Scrollable if there are too many segments for width
- Pannable by holding and moving selection
- Enable or disable specific segments
- Appearance customization thru UIAppearance
- Custom segment width

## TODO:

- Shadow effect / arrows, which show that the segment control is scrollable

# Usage

Import `SDSegmentedControl.h` and `SDSegmentedControl.m` into your
project and add `QuartzCore` framework to `Build Phases` -> `Link Binary With
Libraries`.

You can then use `SDSegmentedControl` class as you would use normal
`UISegmentedControl`.

# Issues:

- Flickering when adding or removing segments in fast interval (in Example project: select the right most, add many, select the left most, remove many, you will see the shadow and border don't move exactly synchronously)
