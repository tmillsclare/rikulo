//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Tue, Jun 05, 2012  9:16:58 AM
// Author: tomyeh

/**
 * A collection of List related utilities.
 */
class ListUtil {
  /** Removes the given object from the list.
   * It returns whether the object is found (and removed).
   * If [list] is null, false is returned.
   */
  static bool remove(List list, var obj) {
    if (list !== null) {
      final int j = list.indexOf(obj);
      if (j >= 0) {
        list.removeRange(j, 1);
        return true;
      }
    }
    return false;
  }

  /** Checks if the given range is allowed in the given list.
   */
  static void rangeCheck(List a, int start, int length) {
    if (length < 0) {
      throw new IllegalArgumentException("negative length $length");
    }
    if (start < 0 || start >= a.length) {
      throw new IndexOutOfRangeException(start);
    }
    if (start + length > a.length) {
      throw new IndexOutOfRangeException(start + length);
    }
  }
}
