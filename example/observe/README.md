## observe

An example implementation of data-observability using read and write
interceptors.

To run the unittest, simply do:
```
pub run test/observe_test.dart
```

The test shows a simple pattern of observability where notifications are
delivered synchronously. It also illustrates that you can observe complex
expressions in getters.

To show how this works in the context of a react-like UI framework, we built an
example under `example/ui/app.dart`. This example shows a sequence of
modifications and how the UI is "re-rendered". This code runs on the
command-line, and the rendered UI is displayed as a single-line of text with
some color highlighting to indicate how the UI was rerendered on a fine-grain
level.

While the observe library issues notifications synchronously, the UI framework
batches changes to render the UI once every event loop.

You can run the example test by doing:
```
pub run example/ui/app.dart
```
