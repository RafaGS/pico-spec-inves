# pico-spec-inves

ESPectrum (1.2) port for Raspberry RP2350 SoC<br/>

I was pleasantly surprised by this port of the ZX Spectrum family to the RP2040/RP2350; I had been missing Inves Plus (Inves +).

So, reusing as much of the existing code for the ZX Spectrum 128K and Pentagon as possible, I added the option to emulate that magnificent "quasi-clone" from Investrónica—bugs and all.

In this fork, Inves starts up by default. It has only been tested on the Waveshare RP2350-PiZero.

Build using:

$ ./build_all.sh ZERO2 

For more information, visit Minibots <https://minibots.wordpress.com>.

Based on https://github.com/drewpo28/pico-spec
