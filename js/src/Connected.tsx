import { Message, MessageStream } from "./MessageStream"

type subscribeCallback = (characteristicUUID: string) => void
interface ConnectedDialogProps {
    deviceID?: string
    gattServices: GattServiceDescription[]
    doSubscribeCallback: subscribeCallback,
    messages: Message[]
}

export enum GattCharacteristicMode {
    Write = "Write",
    Read = "Read",
    Notify = "Notify"
}

export interface GattServiceDescription {
    uuid: string
    characteristics: GattCharacteristicDescription[]
}

export interface GattCharacteristicDescription {
    uuid: string
    modes: GattCharacteristicMode[]
}

const gattServicesRows = (services: GattServiceDescription[], callback: subscribeCallback) =>
    services.flatMap((service) => gattServiceTableRows(service, callback))

const gattServiceTableRows = (service: GattServiceDescription, callback: subscribeCallback) =>
    service.characteristics.map((characteristic) => gattCharacteristicTableRow(service.uuid, characteristic, callback))

const gattCharacteristicTableRow = (serviceUUID: string, characteristic: GattCharacteristicDescription, callback: subscribeCallback) =>
    <tr key={serviceUUID} className="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
        <th scope="row" className="px-6 py-4 font-medium text-gray-900 whitespace-nowrap dark:text-white" >{serviceUUID}</th>
        <td className="px-6 py-4">{characteristic.uuid}</td>
        <td className="px-6 py-4"> {characteristic.modes.join(", ")}</td>
        {
            characteristic.modes.includes(GattCharacteristicMode.Notify) &&
            <td className="px-6 py-4">
                <button
                    className="px-3 py-2 text-xs font-medium text-center text-white bg-blue-700 rounded-lg hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
                    type="button"
                    onClick={() => {
                        callback(characteristic.uuid)
                    }} >Connect</button>
            </td>
        }
    </tr >


export const ConnectedDialog = ({ deviceID, gattServices, doSubscribeCallback, messages }: ConnectedDialogProps) => {
    return (
        <>
            <div className="info-box">
                <p>
                    Connected to: {deviceID}
                </p>
            </div>
            <div className="relative overflow-x-auto shadow-md sm:rounded-lg">
                <table className="w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400">
                    <thead className="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                        <tr>
                            <th scope="col" className="px-6 py-3">
                                Service
                            </th>
                            <th scope="col" className="px-6 py-3">
                                Characteristic
                            </th>
                            <th scope="col" className="px-6 py-3">
                                Modes
                            </th>
                            <th scope="col" className="px-6 py-3">
                                Actions
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {gattServicesRows(gattServices, doSubscribeCallback)}
                    </tbody>
                </table>
            </div>
            {
                messages.length > 0 &&
                < div className="relative overflow-x-auto shadow-md sm:rounded-lg">
                    <MessageStream gattCharacteristicUUID={gattServices[0].uuid} messages={messages}></MessageStream>
                </div >
            }

        </>
    )
}

