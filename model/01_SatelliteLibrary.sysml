/*
 * Simple Space Satellite — SysML v2 educational model
 * File 1 of 6: SatelliteLibrary
 *
 * The "vocabulary" of the model: things that flow between parts (items),
 * signals, value types, ports and interfaces. Everything here is a
 * DEFINITION (keyword "... def"): a reusable type / blueprint.
 * The other packages create USAGES of these definitions.
 */
package SatelliteLibrary {
	doc /* Reusable definitions shared by all other packages of the satellite model. */

	private import ScalarValues::*;
	private import ISQ::*;     // International System of Quantities: MassValue, LengthValue, ...

	/* =====================================================================
	 * 1. Enumerations
	 * ===================================================================== */

	enum def FrequencyBand {
		HF;    // high frequency, 3–30 MHz   (the 20 MHz beacon)
		VHF;   // very high frequency, 30–300 MHz (the 40 MHz beacon)
	}

	/* =====================================================================
	 * 2. Value types (attribute definitions)
	 * ===================================================================== */

	attribute def Orbit {
		doc /* Keplerian description of a (near-Earth) orbit, simplified. */
		attribute perigeeAltitude : LengthValue;
		attribute apogeeAltitude : LengthValue;
		attribute inclination : AngularMeasureValue;
		attribute period : DurationValue;
	}

	/* Signals are attribute definitions that are sent / accepted by behaviour. */
	attribute def SeparationSignal {
		doc /* Sent by the launch vehicle when the satellite is released into orbit. */
	}
	attribute def BatteryDepletedSignal {
		doc /* Raised when the transmitter batteries can no longer power the beacon. */
	}
	attribute def AtmosphericEntrySignal {
		doc /* Raised when atmospheric drag has lowered the orbit enough for re-entry. */
	}

	/* =====================================================================
	 * 3. Items: things that flow through the system
	 * ===================================================================== */

	item def DCPower {
		doc /* Electrical energy delivered as direct current by a battery. */
	}

	item def RFSignal {
		doc /* Radio-frequency signal produced by a transmitter (conducted in a cable, not yet radiated). */
		attribute carrierFrequency : FrequencyValue;
		attribute pulseDuration : DurationValue;
	}

	item def RadioBeacon {
		doc /* The electromagnetic wave radiated by the antennas: the famous "beep-beep". */
		attribute carrierFrequency : FrequencyValue;
	}

	item def HousekeepingData {
		doc /*
		 * Internal temperature and pressure. Sputnik encoded these by changing
		 * the duration of its radio pulses (a very simple form of telemetry).
		 */
		attribute internalTemperature : TemperatureValue;
		attribute internalPressure : PressureValue;
	}

	/* =====================================================================
	 * 4. Ports: interaction points on the boundary of a part
	 *    Each port def is written from the SUPPLIER point of view ("out").
	 *    The receiving side uses the conjugated port  ~PortName  ("in").
	 * ===================================================================== */

	port def PowerPort {
		doc /* Supply side of a DC power connection. */
		out item supply : DCPower;
	}

	port def RFPort {
		doc /* Output of a transmitter (RF connector). */
		out item signal : RFSignal;
	}

	port def DataPort {
		doc /* Output of the sensor unit. */
		out item data : HousekeepingData;
	}

	port def BeaconPort {
		doc /* Radiating side of the radio link (satellite towards Earth). */
		out item beacon : RadioBeacon;
	}

	port def SeparationPort {
		doc /* Mechanical/electrical separation interface on the launch-vehicle side. */
		out attribute release : SeparationSignal;
	}

	/* =====================================================================
	 * 5. Interfaces: typed connections between two ports, with the flows
	 *    they carry.
	 * ===================================================================== */

	interface def PowerInterface {
		doc /* Battery-to-consumer power line. */
		end supplier : PowerPort;
		end consumer : ~PowerPort;
		flow of DCPower from supplier.supply to consumer.supply;
	}

	interface def RFFeedInterface {
		doc /* Coaxial feed from a transmitter to the antenna system. */
		end source : RFPort;
		end sink : ~RFPort;
		flow of RFSignal from source.signal to sink.signal;
	}

	interface def DataInterface {
		doc /* Wiring from the temperature/pressure switches to a transmitter's keyer. */
		end source : DataPort;
		end sink : ~DataPort;
		flow of HousekeepingData from source.data to sink.data;
	}

	interface def RadioLinkInterface {
		doc /* The free-space radio link from the satellite to a receiver on the ground. */
		end spaceSide : BeaconPort;
		end groundSide : ~BeaconPort;
		flow of RadioBeacon from spaceSide.beacon to groundSide.beacon;
	}

	/* =====================================================================
	 * 6. Calculations reused in several places
	 * ===================================================================== */

	calc def BatteryLifetime {
		doc /* Ideal operating time of a battery: stored energy divided by the constant load. */
		in energy : EnergyValue;
		in load : PowerValue;
		return lifetime : DurationValue = energy / load;
	}
}
