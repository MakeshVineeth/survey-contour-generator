// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string'], importedStringConstants: ''};
  return new CompiledApp(
      await _compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string'], importedStringConstants: ''};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

let _isCompileStreamingSupported;
async function _compileStreaming(source, builtins) {
  _isCompileStreamingSupported ??= WebAssembly.compileStreaming(
    new Response(
      new Uint8Array([0,97,115,109,1,0,0,0,1,4,1,96,0,0,2,23,1,14,119,97,115,109,58,106,115,45,115,116,114,105,110,103,4,99,97,115,116,0,0]),
      {headers: {'Content-Type': 'application/wasm'}},
    ),
    builtins,
  ).then(() => false, (e) => e instanceof WebAssembly.CompileError);
  if (await _isCompileStreamingSupported) {
    return WebAssembly.compileStreaming(source, builtins);
  }
  return WebAssembly.compile(await (await source).arrayBuffer(), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      AC: (b, o, l) => new DataView(b, o, l),
      AD: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      AE: (x0,x1) => x0.appendChild(x1),
      AF: (x0,x1) => { x0.action = x1 },
      AG: x0 => x0.documentElement,
      AH: x0 => x0.innerWidth,
      AI: (x0,x1,x2) => x0.insertBefore(x1,x2),
      AJ: x0 => x0.height,
      AK: x0 => x0.style,
      B: s => printToConsole(s),
      BB: Function.prototype.call.bind(String.prototype.toLowerCase),
      BC: Function.prototype.call.bind(DataView.prototype.getUint8),
      BD: x0 => x0.state,
      BE: x0 => x0.debugShowSemanticsNodes,
      BF: (x0,x1) => { x0.method = x1 },
      BG: (x0,x1) => x0.get(x1),
      BH: (x0,x1) => x0.removeChild(x1),
      BI: x0 => x0.id,
      BJ: x0 => x0.width,
      BK: (x0,x1) => { x0.accept = x1 },
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (o, p, r) => o.replace(p, () => r),
      CC: Function.prototype.call.bind(DataView.prototype.setUint8),
      CD: x0 => x0.hash,
      CE: (o, c) => o instanceof c,
      CF: (x0,x1) => { x0.noValidate = x1 },
      CG: x0 => x0.computedStyleMap(),
      CH: x0 => x0.firstChild,
      CI: x0 => x0.offsetHeight,
      CJ: x0 => x0.rasterEndMilliseconds,
      CK: (x0,x1) => { x0.multiple = x1 },
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: (x0,x1) => { x0.lastIndex = x1 },
      DC: Function.prototype.call.bind(DataView.prototype.getFloat64),
      DD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      DE: x0 => x0.vendor,
      DF: x0 => x0.isConnected,
      DG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DH: x0 => x0.viewConstraints,
      DI: x0 => x0.offsetWidth,
      DJ: x0 => x0.rasterStartMilliseconds,
      DK: (x0,x1) => { x0.draggable = x1 },
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      EC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      ED: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      EE: (x0,x1) => x0.createTextNode(x1),
      EF: x0 => x0.click(),
      EG: x0 => x0.matches,
      EH: x0 => x0.hostElement,
      EI: x0 => x0.stopPropagation(),
      EJ: x0 => x0.imageBitmaps,
      EK: (x0,x1) => { x0.type = x1 },
      F: o => String(o),
      FB: o => o instanceof RegExp,
      FC: Function.prototype.call.bind(DataView.prototype.setFloat64),
      FD: x0 => x0.state,
      FE: (x0,x1) => { x0.nonce = x1 },
      FF: (x0,x1) => x0.getElementsByClassName(x1),
      FG: (x0,x1) => x0.matchMedia(x1),
      FH: x0 => ({runApp: x0}),
      FI: x0 => x0.disabled,
      FJ: (x0,x1) => { x0.height = x1 },
      FK: x0 => x0.extraAssets,
      G: () => new Error().stack,
      GB: x0 => x0.dotAll,
      GC: (t, s) => t.set(s),
      GD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      GE: x0 => x0.nonce,
      GF: (x0,x1) => x0.contains(x1),
      GG: x0 => x0.matches,
      GH: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GI: (x0,x1) => { x0.min = x1 },
      GJ: (x0,x1) => { x0.width = x1 },
      GK: x0 => x0.fontManifest,
      H: s => JSON.stringify(s),
      HB: x0 => x0.unicode,
      HC: Function.prototype.call.bind(DataView.prototype.setFloat32),
      HD: (x0,x1) => x0.go(x1),
      HE: () => globalThis.window.flutterConfiguration,
      HF: (s) => +s,
      HG: x0 => x0.timeStamp,
      HH: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      HI: (x0,x1) => { x0.max = x1 },
      HJ: x0 => x0.convertToBlob(),
      HK: x0 => x0.assetManifest,
      I: Function.prototype.call.bind(Number.prototype.toString),
      IB: x0 => x0.ignoreCase,
      IC: Function.prototype.call.bind(DataView.prototype.getFloat32),
      ID: (x0,x1) => x0.append(x1),
      IE: (x0,x1) => x0.attachShadow(x1),
      IF: x0 => x0.target,
      IG: (x0,x1) => x0.hasAttribute(x1),
      IH: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      II: (x0,x1) => { x0.disabled = x1 },
      IJ: (x0,x1,x2) => new ImageData(x0,x1,x2),
      IK: x0 => x0.buildConfig,
      J: Function.prototype.call.bind(String.prototype.indexOf),
      JB: x0 => x0.multiline,
      JC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      JD: (x0,x1) => { x0.textContent = x1 },
      JE: x0 => x0.preventDefault(),
      JF: (x0,x1) => x0.dispatchEvent(x1),
      JG: x0 => x0.type,
      JH: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      JI: (x0,x1) => { x0.scrollLeft = x1 },
      JJ: (x0,x1) => x0.getContext(x1),
      JK: x0 => x0.getReader(),
      K: (s, p, i) => s.lastIndexOf(p, i),
      KB: (o, p, r) => o.replaceAll(p, () => r),
      KC: Function.prototype.call.bind(DataView.prototype.getUint32),
      KD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      KE: (x0,x1) => x0.contains(x1),
      KF: (x0,x1) => x0.createEvent(x1),
      KG: (x0,x1) => x0.getModifierState(x1),
      KH: () => typeof dartUseDateNowForTicks !== "undefined",
      KI: (x0,x1) => { x0.spellcheck = x1 },
      KJ: (x0,x1) => new OffscreenCanvas(x0,x1),
      KK: x0 => x0.value,
      L: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      LB: (x0,x1) => x0[x1],
      LC: Function.prototype.call.bind(DataView.prototype.setUint32),
      LD: x0 => x0.parentElement,
      LE: (x0,x1) => x0.focus(x1),
      LF: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      LG: x0 => x0.buttons,
      LH: () => Date.now(),
      LI: (x0,x1) => { x0.disabled = x1 },
      LJ: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => x0.drawImage(x1,x2,x3,x4,x5,x6,x7,x8,x9),
      LK: x0 => x0.done,
      M: o => o === undefined,
      MB: x0 => x0.length,
      MC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      MD: (x0,x1) => x0.querySelectorAll(x1),
      ME: (x0,x1) => x0.closest(x1),
      MF: x0 => x0.readText(),
      MG: x0 => x0.ctrlKey,
      MH: () => 1000 * performance.now(),
      MI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      MJ: (x0,x1) => x0.getContext(x1),
      MK: x0 => x0.read(),
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: o => o,
      NC: Function.prototype.call.bind(DataView.prototype.getInt32),
      ND: x0 => x0.length,
      NE: (x0,x1) => x0.getAttribute(x1),
      NF: x0 => x0.clipboard,
      NG: x0 => x0.getBoundingClientRect(),
      NH: (x0,x1) => x0.decode(x1),
      NI: (a, s, e) => a.slice(s, e),
      NJ: (x0,x1) => { x0.height = x1 },
      NK: x0 => x0.body,
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      OC: Function.prototype.call.bind(DataView.prototype.setInt32),
      OD: (x0,x1) => x0.item(x1),
      OE: x0 => x0.activeElement,
      OF: (x0,x1) => x0.writeText(x1),
      OG: x0 => x0.y,
      OH: (x0,x1,x2) => x0.slice(x1,x2),
      OI: (x0,x1) => new Blob(x0,x1),
      OJ: (x0,x1) => { x0.width = x1 },
      OK: x0 => x0.assetBase,
      P: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      PB: (x0,x1) => x0.exec(x1),
      PC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      PD: x0 => x0.userAgent,
      PE: (x0,x1) => x0.add(x1),
      PF: x0 => x0.unlock(),
      PG: x0 => x0.x,
      PH: x0 => new Uint8Array(x0),
      PI: x0 => ({type: x0}),
      PJ: x0 => x0.canvasKitMaximumSurfaces,
      PK: x0 => x0.loader,
      Q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QB: x0 => x0.index,
      QC: Function.prototype.call.bind(DataView.prototype.getUint16),
      QD: x0 => x0.maxTouchPoints,
      QE: x0 => x0.classList,
      QF: (x0,x1) => x0.lock(x1),
      QG: x0 => x0.top,
      QH: (x0,x1) => x0.adoptText(x1),
      QI: x0 => globalThis.URL.createObjectURL(x0),
      QJ: x0 => x0.hostElement,
      QK: () => globalThis._flutter,
      R: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      RB: x0 => x0.flags,
      RC: Function.prototype.call.bind(DataView.prototype.setUint16),
      RD: x0 => x0.platform,
      RE: x0 => x0.data,
      RF: x0 => x0.orientation,
      RG: x0 => x0.left,
      RH: x0 => x0.first(),
      RI: (x0,x1) => x0.append(x1),
      RJ: x0 => x0.location,
      S: x0 => new Promise(x0),
      SB: s => s.trim(),
      SC: o => o instanceof Uint16Array,
      SD: x0 => x0.navigator,
      SE: x0 => x0.scrollTop,
      SF: (x0,x1) => x0.querySelector(x1),
      SG: x0 => x0.offsetTop,
      SH: x0 => x0.next(),
      SI: x0 => x0.click(),
      SJ: (x0,x1) => x0.getModifierState(x1),
      T: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      TB: x0 => x0.random(),
      TC: Function.prototype.call.bind(DataView.prototype.getInt16),
      TD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      TE: (handle) => clearTimeout(handle),
      TF: (x0,x1) => { x0.content = x1 },
      TG: x0 => x0.scrollLeft,
      TH: x0 => x0.current(),
      TI: x0 => x0.remove(),
      TJ: x0 => x0.metaKey,
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: () => globalThis.Math,
      UC: Function.prototype.call.bind(DataView.prototype.setInt16),
      UD: Date.now,
      UE: (x0,x1) => x0.removeAttribute(x1),
      UF: x0 => x0.head,
      UG: x0 => x0.offsetLeft,
      UH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      UI: x0 => globalThis.URL.revokeObjectURL(x0),
      UJ: x0 => x0.altKey,
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: (x0,x1) => x0.error(x1),
      VC: o => o instanceof Int16Array,
      VD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      VE: (x0,x1) => { x0.tabIndex = x1 },
      VF: (x0,x1) => { x0.name = x1 },
      VG: x0 => x0.offsetParent,
      VH: x0 => x0.v8BreakIterator,
      VI: x0 => x0.body,
      VJ: x0 => x0.ctrlKey,
      W: x0 => new Array(x0),
      WB: () => globalThis.console,
      WC: o => o instanceof Uint8ClampedArray,
      WD: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      WE: (x0,x1) => { x0.value = x1 },
      WF: (x0,x1) => { x0.title = x1 },
      WG: x0 => x0.offsetY,
      WH: () => globalThis.Intl,
      WI: () => globalThis.document,
      WJ: x0 => x0.isComposing,
      X: o => [o],
      XB: s => s.trimRight(),
      XC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      XD: x0 => x0.style,
      XE: (x0,x1) => { x0.value = x1 },
      XF: () => globalThis.document,
      XG: x0 => x0.offsetX,
      XH: (x0,x1) => x0.segment(x1),
      XI: (x0,x1) => { x0.download = x1 },
      XJ: x0 => x0.code,
      Y: (o0, o1) => [o0, o1],
      YB: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      YC: Function.prototype.call.bind(DataView.prototype.setInt8),
      YD: (x0,x1) => x0.createElement(x1),
      YE: x0 => x0.value,
      YF: (x0,x1) => x0.vibrate(x1),
      YG: x0 => x0.deltaMode,
      YH: x0 => x0.index,
      YI: (x0,x1) => { x0.href = x1 },
      YJ: x0 => x0.repeat,
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: () => ({}),
      ZC: Function.prototype.call.bind(DataView.prototype.getInt8),
      ZD: x0 => x0.body,
      ZE: x0 => x0.selectionDirection,
      ZF: (o, p) => p in o,
      ZG: x0 => x0.deltaY,
      ZH: x0 => x0.next(),
      ZI: (x0,x1) => x0.createElement(x1),
      ZJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: (o, p, v) => o[p] = v,
      aC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      aD: x0 => x0.remove(),
      aE: x0 => x0.selectionStart,
      aF: x0 => x0.arrayBuffer(),
      aG: x0 => x0.deltaX,
      aH: x0 => x0.value,
      aI: (x0,x1) => x0.getRandomValues(x1),
      aJ: (x0,x1) => x0.getElementById(x1),
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: () => [],
      bC: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      bD: (x0,x1) => x0.getPropertyValue(x1),
      bE: x0 => x0.selectionEnd,
      bF: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      bG: x0 => x0.wheelDeltaY,
      bH: x0 => x0.done,
      bI: () => globalThis.crypto,
      bJ: (x0,x1,x2) => x0.setAttribute(x1,x2),
      c: o => o,
      cB: (a, i) => a.push(i),
      cC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      cD: (x0,x1) => x0.warn(x1),
      cE: x0 => x0.value,
      cF: x0 => x0.status,
      cG: x0 => x0.wheelDeltaX,
      cH: (o, m, a) => o[m].apply(o, a),
      cI: l => new DataView(new ArrayBuffer(l)),
      cJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      d: (o, p) => o[p],
      dB: x0 => new Int8Array(x0),
      dC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      dD: x0 => x0.console,
      dE: x0 => x0.selectionDirection,
      dF: (x0,x1) => x0.fetch(x1),
      dG: x0 => x0.bottom,
      dH: x0 => x0.iterator,
      dI: () => new FileReader(),
      dJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      e: () => globalThis,
      eB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      eC: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      eD: (x0,x1) => { x0.id = x1 },
      eE: x0 => x0.selectionStart,
      eF: x0 => x0.content,
      eG: x0 => x0.right,
      eH: () => globalThis.Symbol,
      eI: (x0,x1) => x0.readAsArrayBuffer(x1),
      eJ: (x0,x1) => { x0.target = x1 },
      f: (x0,x1) => ({addView: x0,removeView: x1}),
      fB: x0 => new Uint8Array(x0),
      fC: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      fD: (x0,x1) => x0.requestAnimationFrame(x1),
      fE: x0 => x0.selectionEnd,
      fF: x0 => x0.document,
      fG: x0 => x0.clientY,
      fH: (x0,x1) => new Intl.Segmenter(x0,x1),
      fI: x0 => x0.result,
      fJ: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: x0 => new Uint8ClampedArray(x0),
      gC: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      gD: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gE: (x0,x1) => { x0.name = x1 },
      gF: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      gG: x0 => x0.clientX,
      gH: x0 => x0.Segmenter,
      gI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gJ: (x0,x1) => { x0.innerHTML = x1 },
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      hB: x0 => new Int16Array(x0),
      hC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      hD: x0 => x0.now(),
      hE: (x0,x1) => { x0.placeholder = x1 },
      hF: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      hG: x0 => x0.changedTouches,
      hH: x0 => x0.buffer,
      hI: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      hJ: x0 => x0.document,
      i: (string, token) => string.split(token),
      iB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      iC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      iD: x0 => x0.performance,
      iE: (x0,x1) => { x0.autocomplete = x1 },
      iF: (x0,x1) => x0.querySelector(x1),
      iG: x0 => x0.key,
      iH: x0 => x0.wasmMemory,
      iI: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      iJ: x0 => x0.userAgent,
      j: (a, i) => a[i],
      jB: x0 => new Uint16Array(x0),
      jC: b => !!b,
      jD: (x0,x1) => x0.unregister(x1),
      jE: (x0,x1) => { x0.type = x1 },
      jF: (x0,x1) => x0.querySelectorAll(x1),
      jG: x0 => x0.identifier,
      jH: () => globalThis.window._flutter_skwasmInstance,
      jI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jJ: (x0,x1) => x0.querySelector(x1),
      k: a => a.length,
      kB: x0 => new Int32Array(x0),
      kC: x0 => x0.history,
      kD: () => globalThis.window.FinalizationRegistry,
      kE: (x0,x1) => { x0.name = x1 },
      kF: x0 => x0.tabIndex,
      kG: x0 => x0.touches,
      kH: () => new TextDecoder(),
      kI: () => new XMLHttpRequest(),
      kJ: (x0,x1) => x0.appendChild(x1),
      l: o => o instanceof Array,
      lB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      lC: () => globalThis.window,
      lD: x0 => new window.FinalizationRegistry(x0),
      lE: (x0,x1) => { x0.placeholder = x1 },
      lF: x0 => x0.parentNode,
      lG: x0 => x0.pressure,
      lH: (map, o, v) => map.set(o, v),
      lI: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      lJ: (x0,x1) => { x0.id = x1 },
      m: (string, times) => string.repeat(times),
      mB: x0 => new Uint32Array(x0),
      mC: x0 => x0.search,
      mD: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mE: (x0,x1) => { x0.scrollTop = x1 },
      mF: x0 => x0.clientY,
      mG: x0 => x0.tiltY,
      mH: (map, o) => map.get(o),
      mI: x0 => x0.send(),
      mJ: (x0,x1) => x0.removeChild(x1),
      n: (decoder, codeUnits) => decoder.decode(codeUnits),
      nB: x0 => new Float32Array(x0),
      nC: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      nD: x0 => x0.scale,
      nE: x0 => x0.tagName,
      nF: x0 => x0.clientX,
      nG: x0 => x0.tiltX,
      nH: () => new WeakMap(),
      nI: x0 => x0.type,
      nJ: x0 => x0.firstChild,
      o: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      oB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      oC: x0 => x0.location,
      oD: x0 => x0.visualViewport,
      oE: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      oF: x0 => x0.shiftKey,
      oG: x0 => x0.pointerType,
      oH: x0 => x0.debugSkipFontRetryDelay,
      oI: x0 => x0.response,
      oJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      p: () => new TextDecoder("utf-8", {fatal: true}),
      pB: x0 => new Float64Array(x0),
      pC: x0 => x0.pathname,
      pD: x0 => x0.devicePixelRatio,
      pE: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      pF: x0 => x0.disconnect(),
      pG: x0 => x0.pointerId,
      pH: (x0,x1,x2) => x0.set(x1,x2),
      pI: (x0,x1) => { x0.responseType = x1 },
      pJ: (x0,x1) => x0.item(x1),
      q: () => new TextDecoder("utf-8", {fatal: false}),
      qB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      qC: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      qD: (d, digits) => d.toFixed(digits),
      qE: x0 => x0.visibilityState,
      qF: x0 => new Intl.Locale(x0),
      qG: x0 => x0.getCoalescedEvents(),
      qH: x0 => x0.fontFallbackBaseUrl,
      qI: x0 => x0.vendor,
      qJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      r: s => s.trimLeft(),
      rB: x0 => new ArrayBuffer(x0),
      rC: o => Object.keys(o),
      rD: x0 => x0.maxHeight,
      rE: x0 => x0.hasFocus(),
      rF: x0 => x0.region,
      rG: x0 => x0.blur(),
      rH: x0 => x0.language,
      rI: x0 => x0.navigator,
      rJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      s: (l, r) => l === r,
      sB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      sC: f => f.dartFunction,
      sD: x0 => x0.maxWidth,
      sE: x0 => x0.relatedTarget,
      sF: x0 => x0.script,
      sG: (x0,x1) => x0.setPointerCapture(x1),
      sH: (handle) => clearInterval(handle),
      sI: () => globalThis.window,
      sJ: x0 => x0.name,
      t: s => s.toUpperCase(),
      tB: (x0,x1,x2) => new DataView(x0,x1,x2),
      tC: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      tD: x0 => x0.minHeight,
      tE: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      tF: x0 => x0.language,
      tG: x0 => x0.button,
      tH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      tI: x0 => new Blob(x0),
      tJ: x0 => x0.size,
      u: Object.is,
      uB: (o, p) => o[p],
      uC: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uD: x0 => x0.minWidth,
      uE: x0 => x0.keyCode,
      uF: x0 => x0.languages,
      uG: (x0,x1) => x0.prepend(x1),
      uH: () => Date.now(),
      uI: x0 => globalThis.fetch(x0),
      uJ: x0 => x0.parentNode,
      v: (x0,x1) => x0.test(x1),
      vB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      vC: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      vD: x0 => x0.height,
      vE: (x0,x1) => x0.scrollIntoView(x1),
      vF: (x0,x1) => x0.observe(x1),
      vG: x0 => x0.innerHeight,
      vH: x0 => new WeakRef(x0),
      vI: x0 => x0.arrayBuffer(),
      vJ: x0 => x0.length,
      w: o => o,
      wB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      wC: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      wD: x0 => x0.width,
      wE: x0 => x0.multiViewEnabled,
      wF: x0 => new ResizeObserver(x0),
      wG: x0 => x0.height,
      wH: x0 => x0.deref(),
      wI: o => o.byteLength,
      wJ: x0 => x0.files,
      x: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      xB: o => o.byteOffset,
      xC: (o, i) => o[i],
      xD: x0 => x0.screen,
      xE: x0 => x0.parent,
      xF: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      xG: x0 => x0.width,
      xH: () => globalThis.WeakRef,
      xI: (x0,x1,x2,x3) => x0.putImageData(x1,x2,x3),
      xJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      y: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      yB: o => o.buffer,
      yC: o => o.length,
      yD: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      yE: (x0,x1) => x0.replaceWith(x1),
      yF: x0 => globalThis.parseFloat(x0),
      yG: x0 => x0.clientHeight,
      yH: (a, i) => a.splice(i, 1),
      yI: x0 => x0.arrayBuffer(),
      yJ: x0 => x0.target,
      z: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      zB: (b, o) => new DataView(b, o),
      zC: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      zD: (x0,x1) => x0.removeProperty(x1),
      zE: (x0,x1) => { x0.className = x1 },
      zF: (x0,x1) => x0.getComputedStyle(x1),
      zG: x0 => x0.clientWidth,
      zH: a => a.pop(),
      zI: (x0,x1) => x0.transferFromImageBitmap(x1),
      zJ: (x0,x1) => { x0.display = x1 },

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
