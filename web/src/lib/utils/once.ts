type CallbackFunction = (...args: any[]) => any;

export function once(fn: CallbackFunction | null) {
  return function (...args: any[]) {
    if (fn) fn(...args);
    fn = null;
  };
}
