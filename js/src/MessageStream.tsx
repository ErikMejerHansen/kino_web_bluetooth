export enum MessageFlowDirection {
    Write = 'Write',
    Read = 'Read'
}

export interface Message {
    timestamp: number,
    data: [any, ArrayBuffer],
    direction: MessageFlowDirection
}
interface MessageStreamProps {
    gattCharacteristicUUID: string
    messages: Message[]
}

const formatData = ([_info, data]: [any, ArrayBuffer]) =>
    new Uint8Array(data).map((b: any) => b.toString(16).padStart(2, "0")).join("-")



const messageRow = (message: Message, index: number) => {
    return (
        <tr key={index} className="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
            <td className="px-6 py-4">{message.timestamp}</td>
            <td className="px-6 py-4">{formatData(message.data)}</td>
            <td className="px-6 py-4">{message.direction}</td>
        </tr>
    )
}
export const MessageStream = ({ gattCharacteristicUUID, messages }: MessageStreamProps) => {
    return (
        <>
            <h1>Characteristic: {gattCharacteristicUUID}</h1>
            <div className="relative overflow-x-auto shadow-md sm:rounded-lg">
                <table className="w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400">
                    <thead className="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                        <tr>
                            <th scope="col" className="px-6 py-3">
                                Time
                            </th>
                            <th scope="col" className="px-6 py-3">
                                Data
                            </th>
                            <th scope="col" className="px-6 py-3">
                                Direction
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {messages.map(messageRow)}
                    </tbody>
                </table></div>
        </>
    )
}

