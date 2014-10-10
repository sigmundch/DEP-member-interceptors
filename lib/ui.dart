import 'o2.dart';
import 'dart:async';

linear(list, h) => new LinearLayout(list, h);
input(g, s) => new InputBox(g, s);
button(a, b) => new Button(a, b);
label(a) => new Label(a);

abstract class View {
  View parent;
  bool change = false;
  Binding draw;
 
  View() {
    draw = observe(_renderWithChangeHighlight)..listen(redraw);
  }

  String _renderWithChangeHighlight() {
    var r = render();
    if (change) r = '[32m$r[0m';
    return r;
  }

  String render();

  reset() {
    change = false;
  }

  redraw({bool first: true}) {
    change = first;
    if (parent != null) {
      parent.redraw(first: false);
    } else {
      schedulePrint();
    }
  }

  bool scheduled = false;
  schedulePrint() {
    if (scheduled) return;
    scheduled = true;
    new Future.value().then((_) {
      scheduled = false;
      print(_renderWithChangeHighlight());
      reset();
    });
  }
}

class LinearLayout extends View {
  List subviews;
  final String joiner;
  LinearLayout(this.subviews, bool horizontal)
      : joiner = horizontal ? '' : '\n' {
    subviews.forEach((v) => v.parent = this);
  }

  reset() {
    super.reset();
    subviews.forEach((s) => s.reset());
  }

  String render() => 
      '${subviews.map(ignoreObservers((e) => e.draw.value)).join(joiner)}';
}

class Button extends View {
  var label;
  var action;
  Button(this.label, this.action);
  String render() => '<${label()}>';
  click() => action();
}

class InputBox extends View {
  var read;
  var write;
  InputBox(this.read, this.write);
  String render() => '_${read()}__';

  set value(v) => write(v);
}

class Label extends View {
  var label;
  Label(label)
      : label = label is Function ? label : (() => label);
  String render() => '${label()}';
}
