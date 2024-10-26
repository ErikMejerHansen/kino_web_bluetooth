import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import { BluetoothKino } from './BluetoothKino.tsx'

// Use this file to setup rendering of the component you're currently working on. 
// Run `npm run dev` to setup a dev server with hot module reloads so that you
// can quicky iterate on styling and layouts

// const gattServiceDescription: GattServiceDescription = {
//   uuid: "My-service-uuid",
//   characteristics: [{
//     uuid: "My-characteristic-uuid-1",
//     modes: [GattCharacteristicMode.Read, GattCharacteristicMode.Notify]
//   },
//   {
//     uuid: "My-characteristic-uuid-2",
//     modes: [GattCharacteristicMode.Read]
//   }
//   ]
// }

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <div className='app'>
      <BluetoothKino gattServiceUUID=''></BluetoothKino>
    </div>
  </React.StrictMode>,
)
