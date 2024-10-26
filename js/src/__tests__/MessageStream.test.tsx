import { describe, it, expect } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import { MessageFlowDirection, MessageStream } from '../MessageStream'

describe("The MessageStream component", () => {
    it("shows the characteristic ID as a heading", async () => {
        render(<MessageStream gattCharacteristicUUID="My-UUID" messages={[{ timestamp: Date.now(), data: [{ some: "info" }, Uint8Array.from([]).buffer], direction: MessageFlowDirection.Read }]} />)

        const heading = await screen.findByRole('heading')
        const uuidHeading = await within(heading).findByText("Characteristic: My-UUID")
        expect(uuidHeading).toBeInTheDocument()
    })

    it('has a table', async () => {
        render(<MessageStream gattCharacteristicUUID="My-UUID" messages={[{ timestamp: Date.now(), data: [{ some: "info" }, Uint8Array.from([]).buffer], direction: MessageFlowDirection.Read }]} />)

        const table = await screen.findByRole('table')
        expect(table).toBeInTheDocument()
    })

    it('the messages table has columns for time, data and direction', async () => {

        render(<MessageStream gattCharacteristicUUID="My-UUID" messages={[{ timestamp: Date.now(), data: [{ some: "info" }, Uint8Array.from([]).buffer], direction: MessageFlowDirection.Read }]} />)
        const table = await screen.findByRole('table')

        await within(table).getByText("Time")
        await within(table).getByText("Data")
        await within(table).getByText("Direction")
    })

    it('table has a row for each message', async () => {

        render(<MessageStream gattCharacteristicUUID="My-UUID" messages={[{ timestamp: Date.now(), data: [{ some: "info" }, Uint8Array.from([0x01, 0x02, 0xFF]).buffer], direction: MessageFlowDirection.Write }]} />)
        const table = await screen.findByRole('table')

        const rows = await within(table).findAllByRole('row')

        expect(rows).toHaveLength(1 + 1) // One header + one data row
    })
})
