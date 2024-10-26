import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { ConnectionDialog } from '../ConnectionDialog'

describe("The connection dialog", () => {
    describe("Scan button", () => {
        it("contains a scan button", async () => {
            render(<ConnectionDialog doScanCallback={vi.fn()} />)

            const scanButton = await screen.findByText("Scan")
            expect(scanButton).toBeInTheDocument()
        })

        it("invokes the callback function when clicked", async () => {
            const user = userEvent.setup()

            const mockCallback = vi.fn() as () => void
            render(<ConnectionDialog doScanCallback={mockCallback} />)

            const scanButton = await screen.findByText("Scan")
            await user.click(scanButton)

            expect(mockCallback).toHaveBeenCalledOnce()
        })

        it("passes the service- and characteristic-UUIDs to the callback function", async () => {

            const user = userEvent.setup()

            const mockCallback = vi.fn() as () => void
            render(<ConnectionDialog doScanCallback={mockCallback} />)

            const serviceInput = await screen.findByLabelText("Service UUID")
            await user.type(serviceInput, '00001623-1212-EFDE-1623-785FEABCD123')
            const characteristicInput = await screen.findByLabelText("Characteristic UUID")
            await user.type(characteristicInput, '00001624-1212-EFDE-1623-785FEABCD123')

            const scanButton = await screen.findByText("Scan")
            await user.click(scanButton)

            expect(mockCallback).toHaveBeenCalledWith('00001623-1212-EFDE-1623-785FEABCD123', '00001624-1212-EFDE-1623-785FEABCD123')
        })
    })


    describe("scanning parameters", () => {
        it("contains a input field for setting a GATT Service UUID", async () => {
            render(<ConnectionDialog doScanCallback={vi.fn()} />)

            const serviceInput = await screen.findByLabelText("Service UUID")
            expect(serviceInput).toBeInTheDocument()
        })

        it("contains a input field for setting a GATT Characteristic UUID", async () => {
            render(<ConnectionDialog doScanCallback={vi.fn()} />)

            const characteristicInput = await screen.findByLabelText("Characteristic UUID")
            expect(characteristicInput).toBeInTheDocument()
        })

        it("can have the UUIDs passed as props", async () => {
            render(<ConnectionDialog doScanCallback={vi.fn()} initialServiceUUID='00001623-1212-EFDE-1623-785FEABCD123' initialCharacteristicUUID='00001624-1212-EFDE-1623-785FEABCD123' />)

            const serviceInput = await screen.findByLabelText("Service UUID")
            const characteristicInput = await screen.findByLabelText("Characteristic UUID")

            expect(serviceInput).toHaveValue('00001623-1212-EFDE-1623-785FEABCD123')
            expect(characteristicInput).toHaveValue('00001624-1212-EFDE-1623-785FEABCD123')
        })
    })
})