import { createRoot } from "react-dom/client";
import { ConnectDialog } from "./connect-dialog";

interface Payload {
    gattServiceUUID: string
    gattCharacteristicUUID: string
    variableName: string
}
const buildElements = ({ gattServiceUUID, gattCharacteristicUUID, variableName }: Payload) => {
    return `
    <div class="container">
        <h5>Connection Settings</h5>
        <form>
            <div class="form-group">
                <label>GATT Service</label>
                <input id="gatt_service" value="${gattServiceUUID}" type="text" class="form-control" placeholder="GATT service to scan for">
                <small class="form-text text-muted">If you're scanning for LEGO Wireless Protocol Device use 00001623-1212-EFDE-1623-785FEABCD123</small>
            </div>
            <div class="form-group">
                <label>GATT Characteristic</label>
                <input id="gatt_characteristic" value="${gattCharacteristicUUID}" type="text" class="form-control" placeholder="GATT characteristic to scan for">
                <small class="form-text text-muted">If you're scanning for LEGO Wireless Protocol Device 00001624-1212-EFDE-1623-785FEABCD123</small>
            </div>
            <div class="form-group">
                <label>Variable to save GenServer PID to</label>
                <input id="variable_name" value="${variableName}" type="text" class="form-control" placeholder="Valid Elixir variabel name">
                <small class="form-text text-muted">You'll use this to get access to data from the robot</small>
            </div>
            <button type="button" id="connect" class="btn btn-primary">Connect</button>
        </form>
    </div>
      `;
}


// The payload comes from the `init` callback in elixir land
export const init = (ctx: any, payload: Payload) => {

    // Nice little function if you don't want to handle bundling of CSS youself
    ctx.importCSS('./main.css')

    // Oh.. theres one for JS as well!
    // But it does not support the `integrity` attribute, so use with caution!
    ctx.importJS('https://code.jquery.com/jquery-3.2.1.slim.min.js')
    ctx.importJS('https://cdn.jsdelivr.net/npm/popper.js@1.12.9/dist/umd/popper.min.js')
    ctx.importJS('https://cdn.jsdelivr.net/npm/bootstrap@4.0.0/dist/js/bootstrap.min.js')

    // I do have esbuild setup, but I'm also very lazy...

    // We've got bootstrap, time to build the UI! 
    // - You'll see that a lot of the official smart cells use Vue or React.
    // But we're slumming it here, but HTML in a comment.... not fun
    // We'll use the payload argument to pre-populate input fields
    const root = createRoot(ctx.root)
    root.render(<ConnectDialog></ConnectDialog>)

    // ctx.root.innerHTML = buildElements(payload)


    const gattServiceInput = document.getElementById("gatt_service") as HTMLInputElement;
    const gattCharacteristicInput = document.getElementById("gatt_characteristic") as HTMLInputElement;
    const variableNameInput = document.getElementById("variable_name") as HTMLInputElement;
    const connectButton = document.getElementById("connect") as HTMLInputElement;


    // Setup change event listeners, we need these to ....
    // the elixir side only needs these to serialise the state
    gattServiceInput?.addEventListener("change", (event) => {
        const target = event.target as HTMLInputElement
        ctx.pushEvent("update_gatt_service", target.value);
    });

    // Same as above: only sending because we need to serialise the state
    gattCharacteristicInput?.addEventListener("change", (event) => {
        const target = event.target as HTMLInputElement
        ctx.pushEvent("update_gatt_characteristic", target.value);
    });

    // But this one we'll use for code generation!
    variableNameInput?.addEventListener("change", (event) => {
        const target = event.target as HTMLInputElement
        ctx.pushEvent("update_variable_name", target.value);
    });

    // aaaaaand we need to make sure all the events fire once the livebook has loaded
    // (because the docs told me to....)
    ctx.handleSync(() => {
        // Synchronously invokes change listeners
        document.activeElement &&
            document.activeElement.dispatchEvent(new Event("change"));
    });

    const handleCharacteristicValueChanged = (event: any) => {
        const buffer = new Uint8Array(event.target.value.buffer)

        // Send the message to the Smart Cell
        ctx.pushEvent("value_update", buffer);
    }


    connectButton?.addEventListener("click", () => {
        const target_gatt_service = gattServiceInput?.value?.toLocaleLowerCase()
        const target_gatt_characteristic = gattCharacteristicInput?.value?.toLocaleLowerCase()

        //@ts-ignore: TS does not recongnize that navigator has bluetooth property
        navigator.bluetooth.requestDevice({
            filters: [
                { services: [target_gatt_service] }
            ]
        }).then((device: any) =>  // The user has connected to a device. Connect to the GATT server
            device.gatt.connect()
        ).then((server: any) =>  // GATT server connected. Connect to service
            server.getPrimaryService(target_gatt_service)
        ).then((service: any) => // Connect to the characteristic 
            service.getCharacteristic(target_gatt_characteristic)
        ).then((characteristic: any) =>
            new Promise(resolve => setTimeout(() => resolve(characteristic), 1000))
        ).then((characteristic: any) => {
            const message = Uint8Array.from([
                0x10,
                0x00,
                0x41,
                99,
                0x00, // MODE
                0x06, // DELTA 
                0x00, // DELTA 
                0x00, // DELTA 
                0x00, // DELTA 
                0x01 // Enable notifications
            ])

            characteristic.writeValueWithResponse(message.buffer)

            return characteristic
        }).then((characteristic: any) => {
            return new Promise(resolve => setTimeout(() => resolve(characteristic), 1000));
        }).then((characteristic: any) =>  // Tell the characteristic that we want value updates
            characteristic.startNotifications()
        ).then((characteristic: any) => {  // listen for those value updates
            characteristic.addEventListener('characteristicvaluechanged',
                handleCharacteristicValueChanged)
            return characteristic
        })
    });
}   