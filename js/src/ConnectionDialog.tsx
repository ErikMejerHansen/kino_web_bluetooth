import { ChangeEvent, useState } from "react"

interface ConnectionDialogProps {
  doScanCallback: (serviceUUID: string | undefined, characteristicUUID: string | undefined) => void
  initialServiceUUID?: string
  initialCharacteristicUUID?: string
  serviceUUIDChangeCallback?: (uuid: string) => void
}
export const ConnectionDialog = ({ doScanCallback, initialServiceUUID, initialCharacteristicUUID, serviceUUIDChangeCallback }: ConnectionDialogProps) => {
  const [serviceUUID, setServiceUUID] = useState(initialServiceUUID)
  const [characteristicUUID, setcharacteristicUUID] = useState(initialCharacteristicUUID)

  const handleServiceUUIDChange = (e: ChangeEvent<HTMLInputElement>) => {
    setServiceUUID(e.target.value)
    if (serviceUUIDChangeCallback) {
      serviceUUIDChangeCallback(e.target.value)
    }
  }

  const handleCharacteristicUUID = (e: ChangeEvent<HTMLInputElement>) => {
    setcharacteristicUUID(e.target.value)
  }

  return (
    <>
      <div className="box box-warning">
        <p>No Bluetooth device connected. Click the "Scan" button below to scan and connect to device.
        </p>
        <p>
          Optionally use the Service UUID and Characteristic UUID input below to filter the scan results.
        </p>
      </div>
      <form>
        <div className="space-y-12">
          <div className="border-b border-gray-900/10 pb-12">
            <div className="mt-10 grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
              <div className="sm:col-span-4">
                <label htmlFor="service-uuid" className="block text-sm font-medium leading-6 text-gray-900">
                  Service UUID
                </label>
                <div className="mt-2">
                  <div className="flex rounded-md shadow-sm ring-1 ring-inset ring-gray-300 focus-within:ring-2 focus-within:ring-inset focus-within:ring-indigo-600 sm:max-w-md">
                    <input
                      onChange={handleServiceUUIDChange}
                      defaultValue={serviceUUID}
                      name="service-uuid"
                      id="service-uuid"
                      type="text"
                      className="block flex-1 border-0 bg-transparent py-1.5 pl-1 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm sm:leading-6"
                    />
                  </div>
                </div>
              </div>
              <div className="sm:col-span-4">
                <label htmlFor="characteristic-uuid" className="block text-sm font-medium leading-6 text-gray-900">
                  Characteristic UUID
                </label>
                <div className="mt-2">
                  <div className="flex rounded-md shadow-sm ring-1 ring-inset ring-gray-300 focus-within:ring-2 focus-within:ring-inset focus-within:ring-indigo-600 sm:max-w-md">
                    <input
                      onChange={handleCharacteristicUUID}
                      defaultValue={characteristicUUID}
                      name="characteristic-uuid"
                      id="characteristic-uuid"
                      type="text"
                      className="block flex-1 border-0 bg-transparent py-1.5 pl-1 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm sm:leading-6"
                    />
                  </div>
                </div>
              </div>
            </div>
            <div className="mt-6 flex items-center justify-start gap-x-6">
              <button
                type="button"
                className="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                onClick={() => {
                  doScanCallback(serviceUUID, characteristicUUID)
                }}
              >
                Scan
              </button>
            </div>
          </div>
        </div>
      </form>
    </>
  )
}

