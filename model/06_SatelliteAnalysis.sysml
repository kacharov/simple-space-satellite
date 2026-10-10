/*
 * Simple Space Satellite — SysML v2 educational model
 * File 6 of 6: SatelliteAnalysis
 *
 * Closing the loop: does the design meet its requirements?
 *   - an ANALYSIS case computes the beacon lifetime from the battery energy;
 *   - a VERIFICATION case describes how the mass requirement is tested;
 *   - SATISFY relationships state that the design meets the specification.
 */
package SatelliteAnalysis {
	doc /* Analyses, verification cases and requirement satisfaction for Sputnik 1. */

	private import ISQ::*;
	private import SI::*;
	private import SatelliteLibrary::*;
	private import SatelliteStructure::*;
	private import SatelliteRequirements::*;

	/* =====================================================================
	 * 1. Analysis case: how long can the beacon transmit?
	 * ===================================================================== */

	analysis def BeaconLifetimeAnalysis {
		doc /*
		 * Each transmitter has its own battery. The beacon lifetime is that of
		 * the battery/transmitter chain that runs out first.
		 */
		subject sat : Satellite;

		objective lifetimeObjective {
			doc /* Determine the beacon lifetime and check it against requirement SAT-4. */
			require constraint { predictedLifetime >= minimumLifetime.minLifetime }
		}

		calc chainA : BatteryLifetime {
			in energy = sat.txBatteryA.storedEnergy;
			in load = sat.transmitter20.dcInputPower;
		}

		calc chainB : BatteryLifetime {
			in energy = sat.txBatteryB.storedEnergy;
			in load = sat.transmitter40.dcInputPower;
		}

		return predictedLifetime : DurationValue =
			if chainA.lifetime < chainB.lifetime ? chainA.lifetime else chainB.lifetime;
		// Sputnik 1 (approx. values): 7 MJ / 3.5 W = 2.0E6 s, about 23 days
		// (historically the beacon fell silent after 22 days, on 26 October 1957).
	}

	/* =====================================================================
	 * 2. Verification case: weigh the flight article
	 * ===================================================================== */

	verification def SatelliteWeighingTest {
		doc /* Verify requirement SAT-1 by measuring the mass of the satellite on a scale. */
		private import VerificationCases::*;

		subject testSatellite : Satellite;

		objective weighingObjective {
			verify massLimit;
		}

		action weigh {
			in part testSatellite : Satellite = SatelliteWeighingTest::testSatellite;
			out measuredMass : MassValue;
		}

		action evaluate {
			in measuredMass : MassValue = weigh.measuredMass;
			out verdict : VerdictKind = PassIf(measuredMass <= massLimit.maxMass);
		}

		return verdict : VerdictKind = evaluate.verdict;
	}

	/* =====================================================================
	 * 3. Design context: run the analysis and claim satisfaction
	 * ===================================================================== */

	part sputnikDesignContext {
		doc /* Binds the analysis results to the design and states which requirements it satisfies. */

		analysis lifetimeAnalysis : BeaconLifetimeAnalysis {
			subject sat = design;
		}

		part design :> sputnik1 {
			attribute :>> beaconLifetime = lifetimeAnalysis.predictedLifetime;
		}

		verification weighing : SatelliteWeighingTest {
			subject testSatellite :> design;
		}

		satisfy satelliteSpecification by design;
	}
}
