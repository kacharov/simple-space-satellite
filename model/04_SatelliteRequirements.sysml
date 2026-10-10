/*
 * Simple Space Satellite — SysML v2 educational model
 * File 4 of 6: SatelliteRequirements
 *
 * Requirements in SysML v2 are constraints with a SUBJECT (the thing that
 * must comply). They can carry formal, checkable constraints ("require
 * constraint { ... }") or be purely textual (only a "doc").
 * Pattern used here:  requirement def  ->  requirement usage (with values)
 *                      -> requirement group (the specification).
 */
package SatelliteRequirements {
	doc /* Stakeholder and system requirements for a "simplest satellite". */

	private import ISQ::*;
	private import SI::*;
	private import SatelliteLibrary::*;
	private import SatelliteStructure::*;

	/* =====================================================================
	 * 1. Requirement definitions (reusable, parameterised)
	 * ===================================================================== */

	requirement def MassRequirement {
		doc /* The total mass of the satellite shall not exceed the allowed launch mass. */
		subject sat : Satellite;
		attribute maxMass : MassValue;
		require constraint { sat.totalMass <= maxMass }
	}

	requirement def EnvelopeRequirement {
		doc /* The satellite (antennas folded) shall fit inside the launcher fairing. */
		subject sat : Satellite;
		attribute maxDiameter : LengthValue;
		require constraint { sat.shell.diameter <= maxDiameter }
	}

	requirement def BeaconFrequencyRequirement {
		doc /*
		 * The satellite shall transmit on two frequencies, one in the HF band near
		 * 20 MHz and one in the VHF band near 40 MHz, so that it can be received
		 * by radio amateurs world-wide.
		 */
		subject sat : Satellite;
		attribute tolerance : FrequencyValue;
		require constraint {
			sat.transmitter20.band == FrequencyBand::HF and
			sat.transmitter40.band == FrequencyBand::VHF and
			sat.transmitter20.carrierFrequency >= 20E6 [Hz] - tolerance and
			sat.transmitter20.carrierFrequency <= 20E6 [Hz] + tolerance and
			sat.transmitter40.carrierFrequency >= 40E6 [Hz] - tolerance and
			sat.transmitter40.carrierFrequency <= 40E6 [Hz] + tolerance
		}
	}

	requirement def LifetimeRequirement {
		doc /* The beacon shall operate for at least the minimum mission duration. */
		subject sat : Satellite;
		attribute minLifetime : DurationValue;
		require constraint { sat.beaconLifetime >= minLifetime }
	}

	requirement def ThermalRequirement {
		doc /* The internal temperature shall be kept within the operating range of the electronics. */
		subject sat : Satellite;
		attribute minTemperature : TemperatureValue;
		attribute maxTemperature : TemperatureValue;
		require constraint {
			sat.thermalControl.fanOffTemperature >= minTemperature and
			sat.thermalControl.fanOnTemperature <= maxTemperature
		}
	}

	requirement def TelemetryRequirement {
		doc /*
		 * The beacon shall convey the internal temperature and pressure of the
		 * satellite to ground observers. (A purely textual requirement.)
		 */
		subject sat : Satellite;
	}

	/* =====================================================================
	 * 2. Requirement usages (with concrete values and IDs <'...'>)
	 * ===================================================================== */

	requirement <'SAT-1'> massLimit : MassRequirement {
		subject sat : Satellite;
		attribute :>> maxMass = 90 [kg];
	}

	requirement <'SAT-2'> envelopeLimit : EnvelopeRequirement {
		subject sat : Satellite;
		attribute :>> maxDiameter = 60 [cm];
	}

	requirement <'SAT-3'> beaconFrequencies : BeaconFrequencyRequirement {
		subject sat : Satellite;
		attribute :>> tolerance = 0.1E6 [Hz];
	}

	requirement <'SAT-4'> minimumLifetime : LifetimeRequirement {
		subject sat : Satellite;
		attribute :>> minLifetime = 14 [d];
	}

	requirement <'SAT-5'> thermalRange : ThermalRequirement {
		subject sat : Satellite;
		attribute :>> minTemperature = 273.15 [K];   //  0 °C
		attribute :>> maxTemperature = 323.15 [K];   // 50 °C
	}

	requirement <'SAT-6'> housekeepingTelemetry : TelemetryRequirement {
		subject sat : Satellite;
	}

	/* =====================================================================
	 * 3. The specification: a group of requirements on one subject
	 * ===================================================================== */

	requirement <'SAT'> satelliteSpecification {
		doc /* System specification of the simplest satellite. */
		subject sat : Satellite;

		require massLimit;
		require envelopeLimit;
		require beaconFrequencies;
		require minimumLifetime;
		require thermalRange;
		require housekeepingTelemetry;
	}
}
