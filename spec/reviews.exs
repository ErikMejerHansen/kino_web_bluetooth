# Requirements checked by hand, by requirement ID.
#
# Use this for requirements that tests can't fully cover. Say what was
# checked and how. A requirement whose tests pass doesn't need a review,
# but a review can add what the tests miss (e.g. the browser side).
#
# Update or remove a review when its requirement changes.
%{
  "ARCH-6" =>
    "The browser keeps only the BluetoothDevice and GATT characteristic handles " <>
      "(lib/assets/bluetooth_cell/main.js). Device, value, subscriber and input state " <>
      "live in the Device/Characteristic GenServers and the Smart Cell.",
  "DOC-1" => "README plus module and function docs, reviewed for length and clarity.",
  "TEST-1" =>
    "Tests are grouped in describe blocks per behaviour, with given/when/then helpers " <>
      "(test/support/bluetooth_case.ex).",
  "UI-1" =>
    "Browser side: Service input in the cell header, checked in headless Chromium.",
  "UI-2" =>
    "Connect calls navigator.bluetooth.requestDevice. Checked in headless Chromium " <>
      "with a mocked navigator.bluetooth, not yet with a real device.",
  "UI-3" =>
    "The service input is passed as requestDevice({filters: [{services: [uuid]}]}). " <>
      "Checked in headless Chromium with a mocked navigator.bluetooth.",
  "UI-11" =>
    "Header, inputs and colors follow kino_db's Smart Cells. Compared visually " <>
      "with screenshots, not yet inside Livebook.",
  "API-1" =>
    "UI features and their API: connected status (connected?/1, info/1), " <>
      "services (services/1, characteristics/1), read (read/2), write (write/3), " <>
      "notify (subscribe/2, stream/1), disconnect (disconnect/1). " <>
      "Only picking a device needs the UI."
}
