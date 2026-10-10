/*
 * Simple Space Satellite — SysML v2 educational model
 * File 2 of 6: SatelliteBehavior
 *
 * WHAT the satellite does (actions / functions) and HOW it reacts over time
 * (state machines). Behaviour is defined independently of the hardware;
 * the structure package later says which part performs / exhibits it.
 */
package SatelliteBehavior {
	doc /* Functional (action) and state-based behaviour of the satellite. */

	private import ISQ::*;
	private import SatelliteLibrary::*;

	/* =====================================================================
	 * 1. Functions (action definitions) with inputs and outputs
	 * ===================================================================== */

	action def GenerateCarrier {
		doc /* Turn DC power into a stable radio-frequency carrier (an oscillator). */
		in item power : DCPower;
		out item carrier : RFSignal;
	}

	action def KeyPulses {
		doc /*
		 * Switch the carrier on and off to create the "beep" pulses. The pulse
		 * length depends on the housekeeping data (temperature / pressure).
		 */
		in item data : HousekeepingData;
		in item carrier : RFSignal;
		out item pulses : RFSignal;
	}

	action def RadiateSignal {
		doc /* Convert the conducted RF signal into a radiated electromagnetic wave. */
		in item signal : RFSignal;
		out item beacon : RadioBeacon;
	}

	action def TransmitBeacon {
		doc /* Top-level function of the satellite: tell the world it is in orbit. */
		in item power : DCPower;
		in item data : HousekeepingData;
		out item beacon : RadioBeacon;

		// Decomposition into sub-actions, connected by flows (an activity diagram in text)
		bind generate.power = power;
		action generate : GenerateCarrier { in item power; out item carrier; }

		flow from generate.carrier to key.carrier;
		bind key.data = data;
		action key : KeyPulses { in item data; in item carrier; out item pulses; }

		flow from key.pulses to radiate.signal;
		action radiate : RadiateSignal { in item signal; out item beacon; }
		bind radiate.beacon = beacon;
	}

	action def CirculateNitrogen {
		doc /* Run the internal fan so the nitrogen carries heat from the electronics to the shell. */
		in item power : DCPower;
	}

	/* =====================================================================
	 * 2. State machines
	 * ===================================================================== */

	state def MissionStates {
		doc /* Life cycle of the satellite from launch to re-entry. */

		first start then onLauncher;

		state onLauncher {
			doc /* Integrated under the fairing of the R-7 rocket; transmitters off. */
		}
		accept SeparationSignal
			then transmitting;

		state transmitting {
			doc /* Separated in orbit; the beacon is on (about 3 weeks for Sputnik 1). */
			do action beacon : TransmitBeacon;
		}
		accept BatteryDepletedSignal
			then silentInOrbit;

		state silentInOrbit {
			doc /* Batteries exhausted; the sphere keeps orbiting silently (tracked optically / by radar). */
		}
		accept AtmosphericEntrySignal
			then done;    // the satellite burns up: end of the state machine
	}

	state def ThermalStates {
		doc /*
		 * Simple bang-bang (thermostat) control of the internal temperature.
		 * Uses CHANGE triggers ("accept when <condition>") instead of signals.
		 */
		in measuredTemperature : TemperatureValue;
		in fanOnTemperature : TemperatureValue;
		in fanOffTemperature : TemperatureValue;

		first start then fanOff;

		state fanOff;
		accept when measuredTemperature > fanOnTemperature
			then fanOn;

		state fanOn {
			do action circulate : CirculateNitrogen;
		}
		accept when measuredTemperature < fanOffTemperature
			then fanOff;
	}
}
