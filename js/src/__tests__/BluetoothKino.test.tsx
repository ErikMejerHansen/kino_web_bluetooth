import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'

import { BluetoothKino } from '../BluetoothKino'

describe("App component", () => {
    it("defaults to showing the ConnectedDialog", async () => {
        render(<BluetoothKino gattServiceUUID=''></BluetoothKino>)

        const scanButton = await screen.findByText("Scan")
        expect(scanButton).toBeInTheDocument()
    })
})
