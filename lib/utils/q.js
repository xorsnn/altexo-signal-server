/** Mimic Kris Kowal's Q library, using native promises. */

function Q(executor) {
  return new Promise(executor);
}

module.exports = Object.assign(Q, {
  when: function(valueOrPromise) {
    if (valueOrPromise instanceof Promise) {
      return valueOrPromise;
    }
    return this.resolve(valueOrPromise);
  },

  resolve: function(value) {
    return Q(function(resolve) { resolve(value); });
  },

  reject: function(error) {
    return Q(function(resolve, reject) { reject(error); });
  }
});
