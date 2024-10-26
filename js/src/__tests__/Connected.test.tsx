import { describe, it, expect, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ConnectedDialog, GattCharacteristicMode, GattServiceDescription } from '../Connected'

const gattServiceDescription: GattServiceDescription = {
    uuid: "My-service-uuid",
    characteristics: [{
        uuid: "My-characteristic-uuid-1",
        modes: [GattCharacteristicMode.Read, GattCharacteristicMode.Notify]
    }]
}

describe("The connected dialog", () => {
    describe("Connection Information", () => {
        it("displays the ID of the connected device", async () => {
            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)

            const notification = await screen.findByText("Connected to: LEGO Robot")
            expect(notification).toBeInTheDocument()
        })
    })

    describe("Services Information Table", () => {
        it("has a table", async () => {
            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)

            const table = await screen.findByRole("table")
            expect(table).toBeInTheDocument()
        })

        it("has Service UUID table header", async () => {
            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)
            const table = await screen.findByRole('table')
            const serviceHeader = await within(table).findByText("Service")

            expect(serviceHeader).toBeInTheDocument()
        })

        it("has Characteristic UUID table header", async () => {
            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)
            const table = await screen.findByRole('table')
            const serviceHeader = await within(table).findByText("Characteristic")

            expect(serviceHeader).toBeInTheDocument()
        })

        it("has a row for each GATT Service", async () => {
            const gattServiceDescription: GattServiceDescription = {
                uuid: "My-service-uuid",
                characteristics: [{
                    uuid: "My-characteristic-uuid-1",
                    modes: [GattCharacteristicMode.Read]
                }]
            }

            render(<ConnectedDialog messages={[]} deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} />)
            const table = await screen.findAllByRole('table')
            const rows = await within(table[0]).findAllByRole('row')

            expect(rows).toHaveLength(2)
        })

        it('renders both the service and characteristic UUIDs', async () => {
            const gattServiceDescription: GattServiceDescription = {
                uuid: "My-service-uuid",
                characteristics: [{
                    uuid: "My-characteristic-uuid-1",
                    modes: [GattCharacteristicMode.Read]
                }]
            }

            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)

            await screen.getByText("My-service-uuid")
            await screen.getByText("My-characteristic-uuid-1")
        })

        it('renders the characteristic modes', async () => {


            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)

            await screen.getByText("Read, Notify")
        })

        it('renders the subscribe action when characteristic supports notify', async () => {

            const gattServiceDescription: GattServiceDescription = {
                uuid: "My-service-uuid",
                characteristics: [{
                    uuid: "My-characteristic-uuid-1",
                    modes: [GattCharacteristicMode.Read, GattCharacteristicMode.Notify]
                }]
            }

            render(<ConnectedDialog deviceID={"LEGO Robot"} gattService={gattServiceDescription} doSubscribeCallback={() => { }} messages={[]} />)

            const button = await screen.getByRole("button")

            await within(button).getByText("Connect")
        })
        it('triggers the subscribe callback when the button is cliced', async () => {
            const user = userEvent.setup()
            const mockCallback = vi.fn() as () => void

            const gattServiceDescription: GattServiceDescription = {
                uuid: "My-service-uuid",
                characteristics: [{
                    uuid: "My-characteristic-uuid-1",
                    modes: [GattCharacteristicMode.Read, GattCharacteristicMode.Notify]
                }]
            }

            render(<ConnectedDialog doSubscribeCallback={mockCallback} deviceID={"LEGO Robot"} gattService={gattServiceDescription} messages={[]} />)

            const subscribeButton = await screen.findByText("Connect")
            await user.click(subscribeButton)

            expect(mockCallback).toHaveBeenCalledOnce()
        })

        it("passes the service- and characteristic-UUIDs to the callback function", async () => {

            const user = userEvent.setup()

            const mockCallback = vi.fn() as () => void
            const gattServiceDescription: GattServiceDescription = {
                uuid: "My-service-uuid",
                characteristics: [{
                    uuid: "My-characteristic-uuid-1",
                    modes: [GattCharacteristicMode.Read, GattCharacteristicMode.Notify]
                }]
            }

            render(<ConnectedDialog doSubscribeCallback={mockCallback} deviceID={"LEGO Robot"} gattService={gattServiceDescription} messages={[]} />)

            const subscribeButton = await screen.findByText("Connect")
            await user.click(subscribeButton)

            expect(mockCallback).toHaveBeenCalledWith('My-characteristic-uuid-1')
        })
    })
})
