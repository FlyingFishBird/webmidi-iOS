# webmidi-iOS
iOS 平台上 webmidi 协议的实现

## 使用方式

### 需要导入的 framework

* CoreMIDI.framework
* WebKit.framework

### 添加 MIDI 需要的权限

+ Required background modes
    - App plays audio or streams audio/video using AirPlay
+ App Transport Security Settings
    - Alow Arbitrary Loads
    - Allow Arbitrary Loads in Web Contents

### 需要导入的资源

* WebMIDIAPIPolyfill.js

## 可供查阅的资料

* 使用范例: [webmidi](https://github.com/cotejp/webmidi)
* 参考项目: [WebMIDIAPIShimForiOS](https://github.com/mizuhiki/WebMIDIAPIShimForiOS)
* webmidi 协议: [web-midi-api](https://webaudio.github.io/web-midi-api)
