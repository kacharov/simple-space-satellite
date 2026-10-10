/*
 * Simple Space Satellite — SysML v2 educational model
 * File 3 of 6: SatelliteStructure
 *
 * The physical architecture. It has two halves:
 *   A) PART DEFINITIONS – generic blueprints of the components and of a
 *      "simple satellite" (what parts it has and how they are wired);
 *   B) A PART USAGE  `sputnik1` – one concrete configuration of that
 *      blueprint, filled in with (approximate) Sputnik 1 values.
 */
package SatelliteStructure {
	doc /* Physical architecture of a Sputnik-1-like satellite. */

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SatelliteLibrary::*;
	private import SatelliteBehavior::*;

	/* =====================================================================
	 * A) Component definitions
	 * ===================================================================== */

	part def Shell {
		doc /* Pressurised sphere made of two polished aluminium-alloy hemispheres. */
		attribute diameter : LengthValue;
		attribute wallThickness : LengthValue;
		attribute mass : MassValue;
		attribute internalPressure : PressureValue;   // nitrogen fill
	}

	part def InternalStructure {
		doc /* Internal frame, brackets, wiring and fasteners. */
		attribute mass : MassValue;
	}

	part def Battery {
		doc /* Silver-zinc primary (non-rechargeable) battery. */
		attribute mass : MassValue;
		attribute storedEnergy : EnergyValue;
		port powerOut : PowerPort;
	}

	part def Transmitter {
		doc /* Vacuum-tube radio transmitter that produces the pulsed beacon. */
		attribute mass : MassValue;
		attribute carrierFrequency : FrequencyValue;
		attribute band : FrequencyBand;
		attribute rfOutputPower : PowerValue;
		attribute dcInputPower : PowerValue;
		attribute pulseDuration : DurationValue;

		port powerIn : ~PowerPort;     // conjugated: receives power
		port dataIn : ~DataPort;       // conjugated: receives housekeeping data
		port rfOut : RFPort;

		perform action transmit : TransmitBeacon;   // this part carries out this function
	}

	part def Whip {
		doc /* One spring-loaded whip antenna element. */
		attribute whipLength : LengthValue;
	}

	part def AntennaSystem {
		doc /*
		 * Four whip antennas swept back from the sphere.
		 * Simplification: modelled as one system with one feed per transmitter.
		 */
		attribute mass : MassValue;
		part longWhips : Whip[2];
		part shortWhips : Whip[2];

		port feed20 : ~RFPort;
		port feed40 : ~RFPort;
		port radiated : BeaconPort;
	}

	part def ThermalControlUnit {
		doc /* Fan plus thermal switch: circulates nitrogen so the shell can radiate heat to space. */
		attribute mass : MassValue;
		attribute fanPower : PowerValue;
		attribute fanOnTemperature : TemperatureValue;
		attribute fanOffTemperature : TemperatureValue;
		port powerIn : ~PowerPort;

		perform action circulate : CirculateNitrogen;
	}

	part def SensorUnit {
		doc /* Temperature and pressure switches whose state changes the beacon pulse length. */
		attribute mass : MassValue;
		attribute internalTemperature : TemperatureValue;
		attribute internalPressure : PressureValue;
		port dataOut : DataPort;
	}

	/* =====================================================================
	 * A) The satellite blueprint: decomposition + internal wiring
	 * ===================================================================== */

	part def Satellite {
		doc /* A minimal satellite: a pressurised sphere, batteries, two beacons, antennas, a fan. */

		// ---- Key characteristics -------------------------------------------
		attribute orbit : Orbit;
		attribute beaconLifetime : DurationValue;   // result of an analysis (see SatelliteAnalysis)

		// Derived attribute: the mass roll-up is computed from the parts
		attribute totalMass : MassValue =
			shell.mass + structure.mass +
			txBatteryA.mass + txBatteryB.mass + fanBattery.mass +
			transmitter20.mass + transmitter40.mass +
			antennas.mass + thermalControl.mass + sensors.mass;

		// ---- Parts (composition) -------------------------------------------
		part shell : Shell;
		part structure : InternalStructure;
		part txBatteryA : Battery;          // powers the 20 MHz transmitter
		part txBatteryB : Battery;          // powers the 40 MHz transmitter
		part fanBattery : Battery;          // powers the thermal-control fan
		part transmitter20 : Transmitter;
		part transmitter40 : Transmitter;
		part antennas : AntennaSystem;
		part thermalControl : ThermalControlUnit;
		part sensors : SensorUnit;

		// ---- Boundary ports (how the satellite meets the outside world) ----
		port beaconOut : BeaconPort;
		port separationIn : ~SeparationPort;

		// ---- Internal connections (an internal block diagram in text) -----
		interface powerA : PowerInterface connect txBatteryA.powerOut to transmitter20.powerIn;
		interface powerB : PowerInterface connect txBatteryB.powerOut to transmitter40.powerIn;
		interface powerFan : PowerInterface connect fanBattery.powerOut to thermalControl.powerIn;

		interface data20 : DataInterface connect sensors.dataOut to transmitter20.dataIn;
		interface data40 : DataInterface connect sensors.dataOut to transmitter40.dataIn;

		interface rfFeed20 : RFFeedInterface connect transmitter20.rfOut to antennas.feed20;
		interface rfFeed40 : RFFeedInterface connect transmitter40.rfOut to antennas.feed40;

		// Delegate the antennas' radiating port to the satellite boundary port
		bind antennas.radiated = beaconOut;

		// ---- Behaviour exhibited by the whole satellite --------------------
		exhibit state missionStates : MissionStates;

		exhibit state thermalStates : ThermalStates {
			in measuredTemperature = sensors.internalTemperature;
			in fanOnTemperature = thermalControl.fanOnTemperature;
			in fanOffTemperature = thermalControl.fanOffTemperature;
		}
	}

	/* =====================================================================
	 * B) The concrete design: Sputnik 1 (PS-1), launched 4 October 1957
	 *    ":>>" means "redefines": we give values to features declared above.
	 *    Values marked (approx.) are illustrative estimates for teaching.
	 * ===================================================================== */

	part sputnik1 : Satellite {
		doc /* PS-1 ("Prosteyshiy Sputnik", "simplest satellite"), launched from Baikonur on 4 October 1957. */

		attribute :>> orbit {
			:>> perigeeAltitude = 215 [km];
			:>> apogeeAltitude = 939 [km];
			:>> inclination = 65.1 ['°'];
			:>> period = 96.2 [min];
		}

		part :>> shell {
			:>> diameter = 58 [cm];
			:>> wallThickness = 2 [mm];
			:>> mass = 14.0 [kg];                  // (approx.)
			:>> internalPressure = 131.7E3 [Pa];   // about 1.3 atm of nitrogen
		}

		part :>> structure {
			:>> mass = 10.0 [kg];                  // (approx.)
		}

		// Three silver-zinc batteries, 51 kg in total (approx. 17 kg each)
		part :>> txBatteryA { :>> mass = 17 [kg]; :>> storedEnergy = 7 [MJ]; }   // energy (approx.)
		part :>> txBatteryB { :>> mass = 17 [kg]; :>> storedEnergy = 7 [MJ]; }   // energy (approx.)
		part :>> fanBattery { :>> mass = 17 [kg]; :>> storedEnergy = 7 [MJ]; }   // energy (approx.)

		part :>> transmitter20 {
			:>> carrierFrequency = 20.005E6 [Hz];
			:>> band = FrequencyBand::HF;
			:>> rfOutputPower = 1 [W];
			:>> dcInputPower = 3.5 [W];            // (approx.)
			:>> pulseDuration = 0.3 [s];
			:>> mass = 1.75 [kg];                  // (approx.)
		}

		part :>> transmitter40 {
			:>> carrierFrequency = 40.002E6 [Hz];
			:>> band = FrequencyBand::VHF;
			:>> rfOutputPower = 1 [W];
			:>> dcInputPower = 3.5 [W];            // (approx.)
			:>> pulseDuration = 0.3 [s];
			:>> mass = 1.75 [kg];                  // (approx.)
		}

		part :>> antennas {
			:>> mass = 2.0 [kg];                   // (approx.)
			part :>> longWhips { :>> whipLength = 2.9 [m]; }
			part :>> shortWhips { :>> whipLength = 2.4 [m]; }
		}

		part :>> thermalControl {
			:>> mass = 2.5 [kg];                   // (approx.)
			:>> fanPower = 1 [W];                  // (approx.)
			:>> fanOnTemperature = 309.15 [K];     // 36 °C
			:>> fanOffTemperature = 293.15 [K];    // 20 °C
		}

		part :>> sensors {
			:>> mass = 0.6 [kg];                   // (approx.)
		}
		// totalMass = 14 + 10 + 3*17 + 2*1.75 + 2 + 2.5 + 0.6 = 83.6 kg (the historical value)
	}
}
