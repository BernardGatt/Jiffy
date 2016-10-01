# cocoapods-jiffy

Builds your CocoaPods dependencies in a jiffy.

It creates dynamic frameworks and caches them locally per xcode version, git commit, platform and configuration.

Built libraries are cached in `~/.cocoapods/jiffy-cache`.

This is a fork of [CocoaPods Rome](https://github.com/CocoaPods/Rome) plugin.

It's just some code that helped me to optimize build speed for my projects. If have some issue with it, please make a PR,
 entire code base is ~200 lines, so it's not hard to figure out what went wrong.

## Installation

```bash
$ gem install cocoapods-jiffy
```

## Usage

Write a simple Podfile like this:

```ruby
platform :ios, '9.0' # this will be used as platform for caching

plugin 'cocoapods-jiify'

target 'CoolApp' do
  # just specify targets should be cached by using `cachedpod` instead of `pod`
  # targets will be cached locally per xcode version, commit and configuration (debug/release)
  cachedpod 'RxSwift'
  cachedpod 'RxCocoa'
  cachedpod 'RxDataSources' # if one dependency is meant to be cached, then all of it's dependencies 
                            # will also be cached, so don't list them again using `pod` or it will be
                            # error

  # for other targets just use normal `pod` definition
  pod 'R.swift'         # this is a tool
  pod 'Crashlytics'     # this has already built vendored framework
  pod 'Fabric'          
end
```

then run this:

```bash
BUILD_JIFFY=1 pod install && USE_JIFFY=1 pod install
```

... have no idea can this be done more nicely, so if you can figure out it can be, please shoot me a PR.

and you will end up with optimized Pods directory:

```
$ tree Pods/
├── R.swift
│   ├── License
│   └── rswift
├── Release
│   └── iphoneos
│       ├── RxCocoa
│       │   ├── RxCocoa.Release.podspec
│       │   └── RxCocoa.framework
│       ├── RxDataSources
│       │   ├── RxDataSources.Release.podspec
│       │   └── RxDataSources.framework
│       ├── RxSwift
│       │   ├── RxSwift.Release.podspec
│       │   └── RxSwift.framework
```
