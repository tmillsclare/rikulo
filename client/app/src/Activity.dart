//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Fri, Mar 09, 2012  7:47:30 PM
// Author: tomyeh

/** A switching effect for hiding [from] and displaying [to],
 * such as fade-out and slide-in.
 *
 * + [mask] is the element inserted between [from] and [to]. It is used
 * to block the access of [from].
 */
typedef void ViewSwitchEffect(View from, View to, Element mask);

/**
 * An activity is a UI that the user can interact with.
 * Each activity has a main view called [mainView]. It is the root of
 * the hierarchy tree of views that the user can interact with.
 *
 * To instantiate UI, you have to extend this class and override [onCreate_] to
 * compose your UI and attach it to [mainView] (or replace it).
 *
 *     class HelloWorld extends Activity {
 *       void onCreate_() {
 *         title = "Hello World!";
 *     
 *         TextView welcome = new TextView("Hello World!");
 *         welcome.profile.text = "anchor:  parent; location: center center";
 *         mainView.addChild(welcome);
 *       }
 *     }
 *
 * By default, [mainView] will occupy the whole screen. If you want it to be a part
 * of the screen, you can define an element in the HTML page (that loads the dart
 * application) and assign it the dimension you want and an id called `v-main`. For example,
 *
 *     <link rel="stylesheet" type="text/css" href="../../resources/css/view.css" />
 *     <div id="v-main" style="width:100%;height:200px"></div>
 *     <script type="application/dart" src="HelloWorld.dart"></script>
 *     <script src="../../resources/js/dart.js"></script>
 *
 * If you want to embed multiple application in the same HTML page, you can assign
 * the elements with a different ID, and then invoke [run] with the ID you assigned.
 */
class Activity {
  String _title = "";
  View _mainView;
  final List<_DialogInfo> _dlgInfos;
  Element _container;

  Activity(): _dlgInfos = [] {
    _title = application.name; //also force "get application()" to be called
  }

  /** Returns the main view.
   * The main view is the view the activity is working on.
   * A default view (an instance of [Section]) is created when [run]
   * is called. You can change it to any view you like at any time by
   * calling [set mainView].
   *
   * The main view is a root view, i.e., it doesn't have any parent.
   * In additions, its size has been adjusted to cover the whole screen
   * (or the whole DOM element specified in the containerId parameter of [run] if
   * there is one).
   */
  View get mainView() => _mainView;
  /** Sets the main view.
   */
  void set mainView(View main) {
    setMainView(main);
  }
  /** Sets the main view with an effect.
   */
  void setMainView(View main, [ViewSwitchEffect effect]) {
    if (main === null)
      throw const UIException("mainView can't be null");
    final View prevroot = _mainView;
    _mainView = main;
    if (prevroot !== null) {
      if (main.width === null)
        main.width = prevroot.width;
      if (main.height === null)
        main.height = prevroot.height;

      if (prevroot.inDocument) {
        main.addToDocument(before: prevroot.node);
        prevroot.removeFromDocument();
        //TODO: effect
      }
    }
  }

  /** Returns the topmost dialog, or null if no dialog at all.
   * A dialog is a view sitting on top of [mainView].
   * A dialog is also a root view, i.e., it has no parent.
   *
   * An activity has at most one [mainView], while it might have
   * any number of dialogs. To add a dialog, please use [addPopup].
   * The last added dialog will be on top of the rest, including [mainView].
   */
  View get currentDialog() => _dlgInfos.isEmpty() ? null: _dlgInfos[0].dialog;
  /** Adds a dialog. The dialog will become the topmost view and obscure
   * the other dialogs and [mainView].
   *
   * If specified, [effect] controls how to make the given dialog visible,
   * and the previous dialog or [mainView] invisible.
   *
   * To obscure the dialogs and mainView under it, a semi-transparent mask
   * will be inserted on top of them and underneath the given dialog.
   * You can control the transparent and styles by giving a different CSS
   * class with [maskClass]. If you don't want the mask at all, you can specify
   * `null` to [maskClass]. For example, if the dialog occupies
   * the whole screen, you don't have to generate the mask.
   */
  void addDialog(View dialog, [ViewSwitchEffect effect, String maskClass="v-mask"]) {
    if (dialog.inDocument)
      throw new UIException("Can't be in document: ${dialog}");

    final _DialogInfo dlgInfo = new _DialogInfo(dialog, maskClass);
    _dlgInfos.insertRange(0, 1, dlgInfo);

    final Element parent = new DivElement();
    parent.style.position = "relative";
      //we have to create a relative element to enclose dialog
      //since layout assumes it (test case: TestPartial.html)
    _mainView.node.parent.nodes.add(parent);
    dlgInfo.createMask(parent);
    dlgInfo.dialog.addToDocument(parent);
    //TODO: effect

    broadcaster.sendEvent(new PopupEvent(dialog));
  }
  /** Removes the topmost dialog or the given dialog.
   * If [dialog] is not specified, the topmost one is assumed.
   * If specified, [effect] controls how to make the given dialog invisible,
   * and make the previous dialog or [mainView] visible.
   *
   * It returns false if the given dialog is not found.
   */
  bool removeDialog([View dialog, ViewSwitchEffect effect]) {
    _DialogInfo dlgInfo;
    if (dialog === null) {
      if (_dlgInfos.isEmpty())
        throw const UIException("No dialog at all");

      dlgInfo = _dlgInfos[0];
      _dlgInfos.removeRange(0, 1);
    } else {
      int j = _dlgInfos.length;
      for (;;) {
        if (--j < 0)
          return false;

        dlgInfo = _dlgInfos[j];
        if (dialog == dlgInfo.dialog) {
          _dlgInfos.removeRange(j, 1);
          break;
        }
      }
    }

    final Element parent = dlgInfo.dialog.node.parent;
    dlgInfo.dialog.removeFromDocument();
    dlgInfo.removeMask();
    parent.remove();
    broadcaster.sendEvent(new PopupEvent(null));
    return true;
  }

  /** Returns the DOM element that contains this activity.
   * It is null (by default).
   *
   * If there is a DOM element that matches the `containerId` argument when [run] is
   * called. The DOM element is assumed to be the container, and the activity
   * will be limited to it.
   */
  Element get container() => _container;

  /** Starts the activity.
   * By default, it creates [mainView] (if it was not created yet)
   * and has it to occupies the whole screen.
   *
   * If the DOM element specified in [containerId] is found, [mainView]
   * will only occupy the DOM element. It is useful if you'd like
   * to have multiple activities (i.e., Dart applications) running
   * at the same time and each of them handles only a portion of the
   * screen.
   */
  void run([String containerId="v-main"]) {
    if (activity !== null) //TODO: switching activity (from another activity)
      throw const UIException("Only one activity is allowed");
    if (_mainView !== null)
      throw const UIException("run() called twice?");

    activity = this;

    application._ready(() {
      _init(containerId);

      onCreate_();
      _mainView.requestLayout();
    });
  }
  /** Initializes the browser window, such as registering the events.
   */
  void _init(String containerId) {
    _container = containerId !== null ? document.query("#$containerId"): null;

    Set<String> clses = _container !== null ? _container.classes: document.body.classes;
    clses.add("rikulo");
    clses.add(browser.name);
    if (browser.ios) clses.add("ios");
    else if (browser.android) clses.add("android");

    if (_container !== null)
      updateSize();

    _mainView = new Section();
    _mainView.width = browser.size.width;
    _mainView.height = browser.size.height;
    _mainView.style.overflow = "hidden"; //crop
    _mainView.addToDocument(_container !== null ? _container: document.body);

    (browser.mobile || application.inSimulator ?
      window.on.deviceOrientation: window.on.resize).add((event) { //DOM event
        updateSize();
      });
    (browser.touch ? document.on.touchStart: document.on.mouseDown).add(
      (event) { //DOM event
        broadcaster.sendEvent(new PopupEvent(event.target));
      });
  }
  /** Handles resizing, including device's orientation is changed.
   * It is called automatically, so the application rarely need to call it.
   */
  void updateSize() {
    final DOMQuery qcave = new DOMQuery(_container !== null ? _container: window);
    browser.size.width = qcave.innerWidth;
    browser.size.height = qcave.innerHeight;

    //Note: we have to check if the size is changed, since deviceOrientation
    //will be always fired when the listener is added.
    if (mainView !== null && (mainView.width != browser.size.width
    || mainView.height != browser.size.height)) {
      mainView.width = browser.size.width;
      mainView.height = browser.size.height;
      mainView.requestLayout();
    }
    for (_DialogInfo dlgInfo in _dlgInfos) {
      dlgInfo.resizeMask();
      dlgInfo.dialog.requestLayout();
    }
  }

  /** Returns the title of this activity.
   */
  String get title() => _title;
  /** Sets the title of this activity.
   */
  void set title(String title) {
    document.title = _title = title != null ? title: "";
  }

  /** Called when the activity is starting.
   * You can override this method to create the user interface.
   *
   * The UI you compose will be available to the user after you add it to
   * the hierarchy tree of [mainView].
   *
   * If you prefer to instantiate a different main view, you can
   * create a hierarchy tree of views, and then assign to [mainView] directly.
   * Thus, the hierarchy tree available to the user will become the one you assigned.
   *
   * ##Relation with DOM
   *
   * Before calling this method, [mainView] has been attached to the document.
   * It means all the views added the hierarchy tree of [mainView] will be
   * attached automatically.
   *
   * ##Performance Tips
   *
   * The performance is a little better if you compose UI without adding them
   * to the document first. To do so, you can simply add UI to [mainView] as
   * the last statement. However, the performance improvement is hardly
   * observable unless the UI is very complex (such as hundreds of views).
   */
  void onCreate_() {
  }
  /** Called when the activity is going into background.
   * For example, it is called when there is an incoming phone call.
   *
   * It is meaningful only if it is running as a native mobile application,
   * and [enableDeviceAccess] has been called.
   */
  void onPause_() {
  }
  /** Called when the activity is resumed to start interacting
   * with the user.
   */
  void onResume_() {
  }
  /** Called when the activity is destroyed.
   */
  void onDestroy_() {
  }
}
/** The current activity. */
Activity activity;

class _DialogInfo {
  final View dialog;
  final String maskClass;
  Element _maskNode;

  _DialogInfo(View this.dialog, String this.maskClass);
  void createMask(Element parent) {
    if (maskClass !== null) {
      _maskNode = new Element.html(
        '<div class="v- ${maskClass}" style="width:${browser.size.width}px;height:${browser.size.height}px"></div>');
      if (activity.container !== null) {
        _maskNode.style.position = "absolute";
      }

      parent.$dom_appendChild(_maskNode);
    }
  }
  void resizeMask() {
    if (_maskNode !== null) {
      _maskNode.style.width = CSS.px(browser.size.width);
      _maskNode.style.height = CSS.px(browser.size.height);
    }
  }
  void removeMask() {
    if (_maskNode !== null) {
      _maskNode.remove();
    }
  }
}
