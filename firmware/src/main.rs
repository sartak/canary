#![no_std]
#![no_main]

use bsp::entry;
use bsp::hal::usb::UsbBus;
use bsp::hal::{clocks::init_clocks_and_plls, pac, watchdog::Watchdog};
use panic_halt as _;
use rp_pico as bsp;
use usb_device::{class_prelude::*, prelude::*};
use usbd_serial::SerialPort;

static mut USB_BUS: Option<UsbBusAllocator<UsbBus>> = None;

#[entry]
fn main() -> ! {
    let mut pac = pac::Peripherals::take().unwrap();
    let _core = pac::CorePeripherals::take().unwrap();
    let mut watchdog = Watchdog::new(pac.WATCHDOG);

    let clocks = init_clocks_and_plls(
        bsp::XOSC_CRYSTAL_FREQ,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut watchdog,
    )
    .ok()
    .unwrap();

    let usb_bus = unsafe {
        USB_BUS = Some(UsbBusAllocator::new(UsbBus::new(
            pac.USBCTRL_REGS,
            pac.USBCTRL_DPRAM,
            clocks.usb_clock,
            true,
            &mut pac.RESETS,
        )));
        core::ptr::addr_of!(USB_BUS)
            .as_ref()
            .unwrap_unchecked()
            .as_ref()
            .unwrap()
    };

    let mut serial = SerialPort::new(usb_bus);
    let mut usb_dev = UsbDeviceBuilder::new(usb_bus, UsbVidPid(0x2E8A, 0x000a))
        .strings(&[StringDescriptors::default()
            .manufacturer("shawn.dev")
            .product("Sweep")
            .serial_number("1")])
        .unwrap()
        .device_class(usbd_serial::USB_CLASS_CDC)
        .build();

    let mut tick = 0u32;

    loop {
        if usb_dev.poll(&mut [&mut serial]) {
            let mut buf = [0u8; 64];
            let _ = serial.read(&mut buf);
        }

        tick += 1;
        if tick >= 65000 {
            tick = 0;
            let msg = b"Hello world!\r\n";
            let _ = serial.write(msg);
        }
    }
}
