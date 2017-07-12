function getArgumentNames(fn) {
  const match = fn.toString().match(/\((.+?)?\)/);
  if (match == null)
    throw new Error('cannot parse factory argument names');
  if (match[1] == null)
    return [];
  return match[1].split(',').map(n => n.trim());
}

class Injector {
  constructor() {
    this._defs = new Map();
    this._instances = new Map();
  }

  provide(name, factory) {
    if (typeof name === 'object') {
      (defs => {
        Object.getOwnPropertyNames(defs).forEach(name => {
          this.provide(name, defs[name]);
        });
      })(name);
    }
    else if (typeof name === 'string') {
      this._defs.set(name, factory);
    }
    return this;
  }

  providePath(name, path) {
    if (typeof name === 'object') {
      (defs => {
        Object.getOwnPropertyNames(defs).forEach(name => {
          this.providePath(name, defs[name]);
        });
      })(name);
    }
    else if (typeof name === 'string') {
      this._defs.set(name, require(path));
    }
    return this;
  }

  resolve(name) {
    if (!this._instances.has(name)) {
      const factory = this._defs.get(name);
      const args = getArgumentNames(factory).map(arg => {
        return this.resolve(arg);
      });
      const instance = factory.apply(null, args);
      this._instances.set(name, instance);
    }
    return this._instances.get(name);
  }
}

module.exports = new Injector();
