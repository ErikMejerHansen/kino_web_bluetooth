import ReactDOM from 'react-dom/client'
import { BluetoothKino } from './BluetoothKino'
import { Message } from './MessageStream'

interface Payload {
    gattServiceUUID: string
    gattCharacteristicUUID: string
}


export const init = (ctx: any, { gattServiceUUID }: Payload) => {
    ctx.importCSS('./dev.css')

    const root = ReactDOM.createRoot(ctx.root)
    root.render(
        <div className='app'>
            <BluetoothKino
                kinoCtx={ctx}
                gattServiceUUID={gattServiceUUID}
                serviceUUIDInputChangeCallback={(serviceUUID) => {
                    ctx.pushEvent("update_gatt_service", serviceUUID);
                }}
                messageReceivedCallback={(message: Message) => {
                    ctx.pushEvent("value_update", [{ message: "value_update" }, message.data[1]])
                }}
            />
        </div>
    )
}
