// Web Bluetooth Smart Cell.
//
// All state lives in Elixir and arrives here as views to render. The only
// browser-side state is what the Web Bluetooth API cannot hand over to
// Elixir: the selected device and its GATT characteristic objects.

const PROPERTIES = {
  broadcast: "broadcast",
  read: "read",
  writeWithoutResponse: "write_without_response",
  write: "write",
  notify: "notify",
  indicate: "indicate",
  authenticatedSignedWrites: "authenticated_signed_writes",
  reliableWrite: "reliable_write",
  writableAuxiliaries: "writable_auxiliaries",
};

export function init(ctx, payload) {
  ctx.importCSS("main.css");
  ctx.importCSS(
    "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono&display=swap",
  );

  let bluetoothDevice = null;
  const gattCharacteristics = new Map();

  const formats = payload.formats;
  let fields = payload.fields;
  let device = payload.device;

  ctx.root.innerHTML = `
    <div class="app">
      <div class="header">
        <div class="inline-field grow">
          <label class="inline-input-label" for="service_uuid">Service</label>
          <input class="input grow" id="service_uuid" type="text" spellcheck="false"
            placeholder="heart_rate, 0x180D or a 128-bit UUID" />
        </div>
        <div class="inline-field">
          <label class="inline-input-label" for="variable">Assign to</label>
          <input class="input input--xs" id="variable" type="text" spellcheck="false" />
        </div>
        <button class="button button--primary" id="connect" type="button"></button>
      </div>
      <div class="body" id="body"></div>
    </div>
  `;

  const serviceInput = ctx.root.querySelector("#service_uuid");
  const variableInput = ctx.root.querySelector("#variable");
  const connectButton = ctx.root.querySelector("#connect");
  const body = ctx.root.querySelector("#body");

  // Rendering

  function renderFields() {
    setInputValue(serviceInput, fields.service_uuid);
    setInputValue(variableInput, fields.variable);
    renderConnectButton();
  }

  function renderConnectButton() {
    const connected = device.status === "connected";
    connectButton.textContent = connected ? "Disconnect" : "Connect";
    connectButton.classList.toggle("button--primary", !connected);
    connectButton.disabled = !connected && (!navigator.bluetooth || !serviceInput.value.trim());
  }

  function renderDevice() {
    renderConnectButton();

    if (device.status !== "connected") {
      body.innerHTML = `
        ${
          navigator.bluetooth
            ? `<p class="help">Enter the UUID of a GATT service and click <strong>Connect</strong> to pick a device advertising it.</p>`
            : `<div class="box box--warning">Web Bluetooth is not available in this browser. Use a Chromium based browser, such as Chrome or Edge.</div>`
        }
        ${device.error ? `<div class="box box--error">${escape(device.error)}</div>` : ""}
      `;
      return;
    }

    body.innerHTML = `
      <div class="device">
        <span class="status-dot"></span>
        <span>Connected to <strong>${escape(device.name || "unnamed device")}</strong></span>
      </div>
      ${device.services.map(renderService).join("")}
    `;

    device.services
      .flatMap((service) => service.characteristics)
      .forEach(renderCharacteristicState);
  }

  function renderService(service) {
    return `
      <div class="service">
        <div class="service-header">
          <span class="tag">Service</span>
          ${service.name ? `<span class="name">${escape(service.name)}</span>` : ""}
          <code class="uuid">${escape(service.uuid)}</code>
        </div>
        ${
          service.characteristics.length === 0
            ? `<p class="help">No characteristics.</p>`
            : service.characteristics.map(renderCharacteristic).join("")
        }
      </div>
    `;
  }

  function renderCharacteristic(char) {
    const can = (property) => char.properties.includes(property);
    const writable = can("write") || can("write_without_response");

    return `
      <div class="characteristic" data-key="${escape(char.key)}">
        <div class="characteristic-info">
          ${char.name ? `<span class="name">${escape(char.name)}</span>` : ""}
          <code class="uuid">${escape(char.uuid)}</code>
          <div class="badges">
            ${char.properties.map((p) => `<span class="badge">${escape(p.replace(/_/g, " "))}</span>`).join("")}
          </div>
        </div>
        <div class="characteristic-value">
          <code data-ref="hex"></code>
          <span data-ref="text"></span>
        </div>
        <div class="characteristic-actions">
          ${can("read") ? `<button class="button" type="button" data-action="read">Read</button>` : ""}
          ${
            can("notify") || can("indicate")
              ? `<button class="button" type="button" data-action="subscribe"><span class="status-dot"></span><span data-ref="subscribe"></span></button>`
              : ""
          }
          ${
            writable
              ? `<div class="write">
                  <input class="input input--write" type="text" spellcheck="false" data-ref="write-value" placeholder="Value" />
                  <select class="input" data-ref="write-format">
                    ${formats.map((f) => `<option value="${f}">${f}</option>`).join("")}
                  </select>
                  <button class="button" type="button" data-action="write">Write</button>
                </div>`
              : ""
          }
        </div>
        <div class="characteristic-error" data-ref="error"></div>
      </div>
    `;
  }

  function renderCharacteristicState(char) {
    const row = findRow(char.key);
    if (!row) return;

    const ref = (name) => row.querySelector(`[data-ref="${name}"]`);

    ref("hex").textContent = char.value_hex === null ? "—" : char.value_hex || "(empty)";
    ref("text").textContent = char.value_text === null ? "" : `"${char.value_text}"`;
    ref("error").textContent = char.error || "";

    const subscribe = row.querySelector('[data-action="subscribe"]');
    if (subscribe) {
      subscribe.classList.toggle("notifying", char.notifying);
      ref("subscribe").textContent = char.ui_subscribed ? "Unsubscribe" : "Subscribe";
    }

    renderWriteInput(char.key, char.write);
  }

  function renderWriteInput(key, write) {
    const row = findRow(key);
    if (!row || !row.querySelector('[data-ref="write-value"]')) return;

    setInputValue(row.querySelector('[data-ref="write-value"]'), write.value);
    setInputValue(row.querySelector('[data-ref="write-format"]'), write.format);
  }

  function findRow(key) {
    return [...body.querySelectorAll(".characteristic")].find((row) => row.dataset.key === key);
  }

  // UI events

  serviceInput.addEventListener("input", renderConnectButton);

  serviceInput.addEventListener("change", (event) => {
    ctx.pushEvent("update_field", { field: "service_uuid", value: event.target.value });
  });

  variableInput.addEventListener("change", (event) => {
    ctx.pushEvent("update_field", { field: "variable", value: event.target.value });
  });

  connectButton.addEventListener("click", () => {
    if (device.status === "connected") {
      ctx.pushEvent("disconnect", {});
    } else {
      connect(serviceInput.value);
    }
  });

  body.addEventListener("click", (event) => {
    const button = event.target.closest("[data-action]");
    if (!button) return;

    const row = button.closest(".characteristic");
    const key = row.dataset.key;
    const char = findCharacteristic(key);

    switch (button.dataset.action) {
      case "read":
        ctx.pushEvent("read", { key });
        break;

      case "subscribe":
        ctx.pushEvent("subscribe", { key, enabled: !(char && char.ui_subscribed) });
        break;

      case "write":
        pushWriteInput(row);
        ctx.pushEvent("write", { key });
        break;
    }
  });

  body.addEventListener("change", (event) => {
    const row = event.target.closest(".characteristic");
    if (row && event.target.dataset.ref?.startsWith("write-")) pushWriteInput(row);
  });

  body.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && event.target.dataset.ref === "write-value") {
      event.target.closest(".characteristic").querySelector('[data-action="write"]').click();
    }
  });

  function pushWriteInput(row) {
    ctx.pushEvent("update_write", {
      key: row.dataset.key,
      value: row.querySelector('[data-ref="write-value"]').value,
      format: row.querySelector('[data-ref="write-format"]').value,
    });
  }

  function findCharacteristic(key) {
    return device.services.flatMap((s) => s.characteristics).find((c) => c.key === key);
  }

  // Server events

  ctx.handleEvent("fields", (newFields) => {
    fields = newFields;
    renderFields();
  });

  ctx.handleEvent("device", (newDevice) => {
    device = newDevice;
    renderDevice();
  });

  ctx.handleEvent("characteristic", (char) => {
    device.services.forEach((service) => {
      service.characteristics = service.characteristics.map((c) => (c.key === char.key ? char : c));
    });
    renderCharacteristicState(char);
  });

  ctx.handleEvent("write_input", ({ key, write }) => {
    const char = findCharacteristic(key);
    if (char) char.write = write;
    renderWriteInput(key, write);
  });

  ctx.handleEvent("request", handleRequest);

  ctx.handleSync(() => {
    // Flush pending input changes before evaluation
    document.activeElement && document.activeElement.dispatchEvent(new Event("change", { bubbles: true }));
  });

  // Web Bluetooth

  async function connect(serviceUuid) {
    const service = toServiceFilter(serviceUuid);
    if (!service) return;

    try {
      const selected = await navigator.bluetooth.requestDevice({ filters: [{ services: [service] }] });

      forgetDevice();
      bluetoothDevice = selected;
      bluetoothDevice.addEventListener("gattserverdisconnected", handleDisconnected);

      const server = await bluetoothDevice.gatt.connect();
      const services = [];

      for (const service of await server.getPrimaryServices()) {
        const characteristics = await service.getCharacteristics().catch(() => []);

        services.push({
          uuid: service.uuid,
          characteristics: characteristics.map((char) => {
            gattCharacteristics.set(`${service.uuid}/${char.uuid}`, char);
            return { uuid: char.uuid, properties: propertyNames(char.properties) };
          }),
        });
      }

      ctx.pushEvent("connected", { name: bluetoothDevice.name || bluetoothDevice.id, services });
    } catch (error) {
      if (bluetoothDevice && bluetoothDevice.gatt.connected) bluetoothDevice.gatt.disconnect();
      ctx.pushEvent("connect_error", { message: error.message || String(error) });
    }
  }

  async function handleRequest({ ref, op, service, characteristic, value }) {
    if (op === "disconnect") {
      if (bluetoothDevice && bluetoothDevice.gatt.connected) bluetoothDevice.gatt.disconnect();
      return;
    }

    const reply = (result) => ctx.pushEvent("response", { ref, service, characteristic, ...result });
    const char = gattCharacteristics.get(`${service}/${characteristic}`);

    if (!char) {
      reply({ error: "characteristic not available" });
      return;
    }

    try {
      switch (op) {
        case "read":
          reply({ value: toBytes(await char.readValue()) });
          break;

        case "write":
          await char.writeValueWithResponse(new Uint8Array(value));
          reply({ value: null });
          break;

        case "write_without_response":
          await char.writeValueWithoutResponse(new Uint8Array(value));
          reply({ value: null });
          break;

        case "start_notifications":
          char.addEventListener("characteristicvaluechanged", handleValueChanged);
          await char.startNotifications();
          reply({ value: null });
          break;

        case "stop_notifications":
          char.removeEventListener("characteristicvaluechanged", handleValueChanged);
          await char.stopNotifications();
          reply({ value: null });
          break;

        default:
          reply({ error: `unknown operation ${op}` });
      }
    } catch (error) {
      reply({ error: error.message || String(error) });
    }
  }

  function handleValueChanged(event) {
    const char = event.target;

    ctx.pushEvent("notification", {
      service: char.service.uuid,
      characteristic: char.uuid,
      value: toBytes(char.value),
    });
  }

  function handleDisconnected(event) {
    if (event.target !== bluetoothDevice) return;
    gattCharacteristics.clear();
    ctx.pushEvent("disconnected", {});
  }

  function forgetDevice() {
    if (!bluetoothDevice) return;
    bluetoothDevice.removeEventListener("gattserverdisconnected", handleDisconnected);
    if (bluetoothDevice.gatt.connected) bluetoothDevice.gatt.disconnect();
    bluetoothDevice = null;
    gattCharacteristics.clear();
  }

  renderFields();
  renderDevice();
}

// Web Bluetooth takes 16/32-bit aliases as numbers, full UUIDs and
// standard names (like "heart_rate") as strings.
function toServiceFilter(input) {
  const value = input.trim().toLowerCase();
  if (!value) return null;

  if (/^(0x)?([0-9a-f]{4}|[0-9a-f]{8})$/.test(value)) {
    return parseInt(value.replace(/^0x/, ""), 16);
  }

  return value;
}

function propertyNames(properties) {
  return Object.keys(PROPERTIES)
    .filter((property) => properties[property])
    .map((property) => PROPERTIES[property]);
}

function toBytes(dataView) {
  return Array.from(new Uint8Array(dataView.buffer, dataView.byteOffset, dataView.byteLength));
}

function setInputValue(input, value) {
  if (document.activeElement !== input && input.value !== value) {
    input.value = value;
  }
}

function escape(string) {
  return String(string)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
