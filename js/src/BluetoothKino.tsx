import { useEffect, useState } from "react"
import { ConnectionDialog } from "./ConnectionDialog"
import { ConnectedDialog, GattCharacteristicDescription, GattCharacteristicMode, GattServiceDescription } from "./Connected"
import { Message, MessageFlowDirection } from "./MessageStream"
import { Queue } from "./queue"

interface BluetoothKinoProps {
    gattServiceUUID: string
    serviceUUIDInputChangeCallback?: (uuid: string) => void
    messageReceivedCallback?: (message: Message) => void
    kinoCtx?: any
}

const buildGattCharacteristicModes = (gattCharacteristic: any): GattCharacteristicMode[] => {
    const modes = []

    if (gattCharacteristic.properties.read) {
        modes.push(GattCharacteristicMode.Read)
    }

    if (gattCharacteristic.properties.write) {
        modes.push(GattCharacteristicMode.Write)
    }

    if (gattCharacteristic.properties.notify) {
        modes.push(GattCharacteristicMode.Notify)
    }

    return modes
}

const buildGattCharacteristicDescription = (gattCharacteristic: any): GattCharacteristicDescription => {
    return {
        uuid: gattCharacteristic.uuid,
        modes: buildGattCharacteristicModes(gattCharacteristic)
    }

}
const buildGattServiceDescription = (serviceUUID: string, gattCharacteristics: any): GattServiceDescription => {
    const characteristicDescriptions = gattCharacteristics.map(buildGattCharacteristicDescription)
    return {
        uuid: serviceUUID ? serviceUUID : "",
        characteristics: characteristicDescriptions
    }
}

const buildMessage = (event: any): Message => {
    return {
        timestamp: event.timeStamp,
        data: [{ "value": "changed" }, event.target.value.buffer],
        direction: MessageFlowDirection.Read
    }
}
const lwpToRobotQueue = new Queue()

export const BluetoothKino = ({ gattServiceUUID, serviceUUIDInputChangeCallback, messageReceivedCallback, kinoCtx }: BluetoothKinoProps) => {
    const [isDeviceConnected, setIsDeviceconnected] = useState<boolean>(false)
    const [deviceName, setDeviceName] = useState<string>("")
    const [gattService, setGattService] = useState<GattServiceDescription>()
    const [connectedService, setConnectedService] = useState<any>()
    const [messages, setMessages] = useState<Message[]>([])
    const [eventHandlersSet, setEventHandlersSet] = useState<boolean>(false)
    const [_subscribedGattCharacteristic, setSubscribedCharacteristic] = useState<any>()

    const writeToSubscribedCharacterisric = (message: Message) => {
        // Don't do this... but I ran out of time...😱
        setSubscribedCharacteristic((characteristic: any) => {
            lwpToRobotQueue.enqueue(() => { return characteristic.writeValueWithoutResponse(message.data[1]) })
            return characteristic
        })
    }

    useEffect(() => {
        if (eventHandlersSet) {
            return
        }

        if (!kinoCtx) {
            return
        }

        // The Kino context does not like having the same event-handler set twice
        setEventHandlersSet(true)

        // Handle the write events that are sent from the backend when Elixir code wants to write data
        kinoCtx.handleEvent("write", (data: any) => {
            console.log("Incomming data", data)
            const message: Message = {
                timestamp: Date.now(),
                data: data,
                direction: MessageFlowDirection.Write
            }

            setMessages((previousMessages) => {
                console.log(message)
                return [...previousMessages, message]
            })
            // TODO: This throws an error on the clients that are not connected to the device?
            writeToSubscribedCharacterisric(message)
        }, []);

        kinoCtx.handleEvent("value_update", (data: any) => {
            const message = {
                timestamp: Date.now(),
                data: data,
                direction: MessageFlowDirection.Read
            }

            setMessages((previousMessages) => {
                return [...previousMessages, message]
            })
        })

        kinoCtx.handleEvent("device_connected", (payload: any) => {
            console.log("Device connected", payload)
            setGattService(payload)
            setIsDeviceconnected(true)
        })
    })

    const scan = (serviceUUID?: string, _characteristicUUID?: string) => {
        const scanOptions = serviceUUID ? { filters: [{ services: [serviceUUID] }] } : { acceptAllDevices: true }
        //@ts-ignore: TS does not recongnize that navigator has bluetooth property
        navigator.bluetooth.requestDevice(scanOptions)
            .then((device: any) => {  // The user has connected to a device. Connect to the GATT server
                const gattServer = device.gatt.connect()
                setDeviceName(device.name)
                return gattServer
            })
            .then((server: any) =>   // GATT server connected. Connect to service
                server.getPrimaryService(serviceUUID)
            ).then((service: any) => {
                setConnectedService(service)
                return service.getCharacteristics()
            }).then((characteristics: any) => {
                const uuid = serviceUUID ? serviceUUID : ""
                const serviceDescription = buildGattServiceDescription(uuid, characteristics)

                console.log("sending services", [serviceDescription])
                // Tell the backend that a device has sucessfully connected
                kinoCtx.pushEvent("device_connected", serviceDescription)

            })
    }

    const subscribe = (characteristicUUID: string) => {
        connectedService.getCharacteristic(characteristicUUID)
            .then((characteristic: any) => {
                // Tell the characteristic that we want value updates
                characteristic.startNotifications()

                return characteristic
            }
            ).then((characteristic: any) => {  // listen for those value updates
                setSubscribedCharacteristic(characteristic)

                characteristic.addEventListener('characteristicvaluechanged',
                    (event: any) => {
                        const message = buildMessage(event)
                        if (messageReceivedCallback) {
                            messageReceivedCallback(message)
                        }
                    })
            })
    }

    return (
        <>
            {
                isDeviceConnected
                    ? <ConnectedDialog deviceID={deviceName} doSubscribeCallback={subscribe} gattService={gattService} messages={messages}></ConnectedDialog>
                    : <ConnectionDialog doScanCallback={scan} initialServiceUUID={gattServiceUUID} serviceUUIDChangeCallback={serviceUUIDInputChangeCallback}></ConnectionDialog>
            }
        </>
    )
}