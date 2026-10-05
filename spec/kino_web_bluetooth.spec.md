# EARS
## Syntax: While <optional pre-condition>, when <optional trigger>, the <system name> shall <system response>
## Examples
Ubiquitous requirements
Ubiquitous requirements are always active (so there is no EARS keyword)

The <system name> shall <system response>

Example: The mobile phone shall have a mass of less than XX grams.

State driven requirements
State driven requirements are active as long as the specified state remains true and are denoted by the keyword While.

While <precondition(s)>, the <system name> shall <system response>

Example: While there is no card in the ATM, the ATM shall display “insert card to begin”.

Event driven requirements
Event driven requirements specify how a system must respond when a triggering event occurs and are denoted by the keyword When.

When <trigger>, the <system name> shall <system response>

Example: When “mute” is selected, the laptop shall suppress all audio output.

Optional feature requirements
Optional feature requirements apply in products or systems that include the specified feature and are denoted by the keyword Where.

Where <feature is included>, the <system name> shall <system response>

Example: Where the car has a sunroof, the car shall have a sunroof control panel on the driver door.

Unwanted behaviour requirements
Unwanted behaviour requirements are used to specify the required system response to undesired situations and are denoted by the keywords If and Then.

If <trigger>, then the <system name> shall <system response>

Example: If an invalid credit card number is entered, then the website shall display “please re-enter credit card details”.

Complex requirements
The simple building blocks of the EARS patterns described above can be combined to specify requirements for richer system behaviour. Requirements that include more than one EARS keyword are called Complex requirements.

While <precondition(s)>, When <trigger>, the <system name> shall <system response>

# Requirement IDs

Every requirement is a list item starting with a unique ID, like
`- [UI-4] The KinoWebBluetooth UI shall ...`. Tests and reviews refer
to requirements by ID, so:

- To add a requirement, give it the next free ID in its section.
- To reword a requirement without changing its meaning, keep its ID.
- To change what a requirement means, give it a new ID. Its old tests
  and reviews then no longer count, until they are updated.
- To remove a requirement, delete it. Never reuse its ID.

Run `mix spec` to see which requirements are implemented, in
[STATUS.md](STATUS.md).

# Spec

## Architecture
- [ARCH-1] The hex package name for this KinoSmartCell shall be kino_web_bluetooth
- [ARCH-2] The top level namespace for this project shall be KinoWebBluetooth

- [ARCH-3] The KinoWebBluetooth shall have a UI for use in a Livebook
- [ARCH-4] The KinoWebBluetooth shall have a programmatic API

- [ARCH-5] The KinoWebBluetooth shall have a GenServer per characteristic
- [ARCH-6] The KinoWebBluetooth shall keep state in Elixir except where strictly needed

## Documentation
- [DOC-1] The KinoWebBluetooth shall have concise and easy to read documentation

## Testing
- [TEST-1] The KinoWebBluetooth shall have easy to read tests in a BDD style

## UI
- [UI-1] The KinoWebBluetooth UI shall show an input field that allows entering a BLE GATT Service UUID
- [UI-2] The KinoWebBluetooth UI shall show a button that triggers browser BLE device Selector
- [UI-3] The KinoWebBluetooth UI shall pass the user provided service UUID to the browser's BLE functionality
- [UI-4] The KinoWebBluetooth UI shall show if a BLE device is connected
- [UI-5] The KinoWebBluetooth UI shall show information of the services on the connected device
- [UI-6] The KinoWebBluetooth UI shall show information about the characteristics of the services
- [UI-7] The KinoWebBluetooth UI shall show buttons that allow connecting to NOTIFY characteristics
- [UI-8] The KinoWebBluetooth UI shall show buttons that allow reading a value from a READ characteristic
- [UI-9] The KinoWebBluetooth UI shall show UI to allow writing to a WRITE characteristic
- [UI-10] The KinoWebBluetooth UI shall persist user input as part of the Livebook
- [UI-11] The KinoWebBluetooth UI shall match the UX/UI of the official Kino Smart Cells
- [UI-12] The KinoWebBluetooth UI shall show the messages received over characteristics

## Programmatic API
- [API-1] The KinoWebBluetooth API shall have the same functionality as the UI except where the browser requires direct user input
- [API-2] The KinoWebBluetooth API shall allow subscribing to async messages from GenServers representing NOTIFY characteristics
- [API-3] The KinoWebBluetooth API shall allow sync and async write to GenServers representing WRITE characteristics
- [API-4] The KinoWebBluetooth API shall have sync functionality to read from GenServers representing READ characteristics
