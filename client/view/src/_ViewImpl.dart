//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Tue, Mar 13, 2012  2:14:29 PM
// Author: tomyeh

/** Collection of utilities for View's implementation
 */
class _ViewImpl {
  //Link//
  //----//
  static void link(View view, View child, View beforeChild) {
    final _ChildInfo ci = view._initChildInfo();
    if (beforeChild === null) {
      View p = ci.lastChild;
      if (p !== null) {
        p._nextSibling = child;
        child._prevSibling = p;
        ci.lastChild = child;
      } else {
        ci.firstChild = ci.lastChild = child;
      }
    } else {
      View p = beforeChild._prevSibling;
      if (p !== null) {
        child._prevSibling = p;
        p._nextSibling = child;
      } else {
        ci.firstChild = child;
      }

      beforeChild._prevSibling = child;
      child._nextSibling = beforeChild;
    }
    child._parent = view;

    ++view._childInfo.nChild;
    if (child is IdSpace)
      addToIdSpace(child, true); //skip the first owner (i.e., child)
    else
      addToIdSpaceDown(child, child.spaceOwner);
  }
  static void unlink(View view, View child) {
    if (child is IdSpace)
      removeFromIdSpace(child, true); //skip the first owner (i.e., child)
    else
      removeFromIdSpaceDown(child, child.spaceOwner);

    var p = child._prevSibling, n = child._nextSibling;
    if (p !== null) p._nextSibling = n;
    else view._childInfo.firstChild = n;
    if (n !== null) n._prevSibling = p;
    else view._childInfo.lastChild = p;
    child._nextSibling = child._prevSibling = child._parent = null;

    --view._childInfo.nChild;
  }

  //Event Handlign//
  //--------------//
  static DOMEventDispatcher getDOMEventDispatcher(String type) {
    if (_domEvtDisps === null) {
      _domEvtDisps = {};
      for (final String nm in
      const ["click", "blur", "focus", "change", "mouseDown", "mouseUp", "mouseOver", "mouseOut"]) {
        _domEvtDisps[nm] = _domEvtDisp(nm);
      }
    }
    return _domEvtDisps[type];
  }
  static DOMEventDispatcher _domEvtDisp(String type) {
    return (View target) {
      return (Event event) {
        target.sendEvent(new ViewEvent.dom(target, event, type: type));
      };
    };
  }
  static Map<String, DOMEventDispatcher> _domEvtDisps;

  //IdSpace//
  //-------//
  static IdSpace spaceOwner(View view) {
    View top, p = view;
    do {
      if (p is IdSpace)
        return _cast(p);
      top = p;
    } while ((p = p.parent) != null);

    if (top._virtIS === null)
      top._virtIS = new _VirtualIdSpace(top);
    return top._virtIS;
  }
  static _cast(var v) => v; //TODO: remove it when Dart allows to cast to any type, not just downcast

  /** Checks the uniqueness in ID space when changing ID. */
  static void checkIdSpaces(View view, String newId) {
    IdSpace space = view.spaceOwner;
    if (space.getFellow(newId) !== null)
      throw new UIException("Not unique in the ID space of $space: $newId");

    //we have to check one level up if view is IdSpace (i.e., unique in two ID spaces)
    View parent;
    if (view is IdSpace && (parent = view.parent) != null) {
      space = parent.spaceOwner;
      if (space.getFellow(newId) !== null)
        throw new UIException("Not unique in the ID space of $space: $newId");
    }
  }
  //Add the given view to the ID space
  static void addToIdSpace(View view, [bool skipFirst=false]){
    String id = view.id;
    if (id.length == 0)
      return;

    if (!skipFirst) {
      var space = _cast(view.spaceOwner);
      space.bindFellow_(id, view);
    }

    //we have to put it one level up if view is IdSpace (i.e., unique in two ID spaces)
    View parent;
    if (view is IdSpace && (parent = view.parent) != null) {
      var space = _cast(parent.spaceOwner);
      space.bindFellow_(id, view);
    }
  }
  //Add the given view and all its children to the ID space
  static void addToIdSpaceDown(View view, var space) {
    var id = view.id;
    if (id.length > 0)
      space.bindFellow_(id, view);

    if (view is! IdSpace) {
      final IdSpace vs = view._virtIS;
      if (vs !== null) {
        view._virtIS = null;
        for (final View child in vs.fellows)
          space.bindFellow_(child.id, child);
      } else {
        for (view = view.firstChild; view != null; view = view.nextSibling)
          addToIdSpaceDown(view, space);
      }
    }
  }
  static void removeFromIdSpace(View view, [bool skipFirst=false]) {
    String id = view.id;
    if (id.length == 0)
      return;

    if (!skipFirst) {
      var space = _cast(view.spaceOwner);
      space.bindFellow_(id, null);
    }

    //we have to put it one level up if view is IdSpace (i.e., unique in two ID spaces)
    View parent;
    if (view is IdSpace && (parent = view.parent) != null) {
      var space = _cast(parent.spaceOwner);
      space.bindFellow_(id, null);
    }
  }
  static void removeFromIdSpaceDown(View view, var space) {
    var id = view.id;
    if (id.length > 0)
      space.bindFellow_(id, null);

    if (view is! IdSpace)
      for (view = view.firstChild; view != null; view = view.nextSibling)
        removeFromIdSpaceDown(view, space);
  }
}

/** The children information used in [View].
 */
class _ChildInfo {
  View firstChild, lastChild;
  int nChild = 0;
  List children;
}

/** The information of an event listener used in [View].
 */
class _EventListenerInfo {
  ViewEvents on;
  //the registered event listeners; created on demand
  Map<String, List<ViewEventListener>> listeners;
  //generic DOM event listener
  Map<String, EventListener> domListeners;
}

/** The classes stored in a view.
 */
class _ClassSet extends HashSetImplementation<String> {
  final View view;

  _ClassSet(View this.view);

  void add(String name) {
    super.add(name);
    final Element n = view.node;
    if (n != null)
      n.classes.add(name);
  }
  bool remove(String name) {
    final bool removed = super.remove(name);
    if (removed) {
      final Element n = view.node;
      if (n != null)
        n.classes.remove(name);
    }
    return removed;
  }
  void clear() {
    super.clear();
    final Element n = view.node;
    if (n != null)
      n.classes.clear();
  }
}

/** A virtual ID space.
 */
class _VirtualIdSpace implements IdSpace {
  View _owner;
  Map<String, View> _fellows;

  _VirtualIdSpace(this._owner): _fellows = {};
  
  View query(String selector) => _owner.query(selector);
  List<View> queryAll(String selector) => _owner.queryAll(selector);

  View getFellow(String id) => _fellows[id];
  void bindFellow_(String id, View fellow) {
    if (fellow !== null) _fellows[id] = fellow;
    else _fellows.remove(id);
  }
  Collection<View> get fellows() => _fellows.getValues();
  String toString() => "_VirtualIdSpace($_owner: $_fellows)";
}

RunOnceViewManager get _invalidator() {
  if (_$invalidator == null)
    _$invalidator = new RunOnceViewManager((View view) {view.invalidate(true);});
  return _$invalidator;
}
RunOnceViewManager _$invalidator;
