/*
 * Simple Space Satellite — SysML v2 educational model
 * File 5 of 6: SatelliteMissionContext
 *
 * The satellite in its environment: the launch vehicle that releases it,
 * the ground stations that listen to it, and the use case that explains
 * WHY the system exists.
 */
package SatelliteMissionContext {
	doc /* Operational context and use case of the satellite mission. */

	private import ScalarValues::*;
	private import SatelliteLibrary::*;
	private import SatelliteStructure::*;

	/* =====================================================================
	 * 1. External systems (actors)
	 * ===================================================================== */

	part def LaunchVehicle {
		doc /* The R-7 (8K71PS) rocket that placed the satellite into orbit. */
		port separationOut : SeparationPort;

		action releasePayload {
			send new SeparationSignal() via separationOut;
		}
	}

	part def GroundStation {
		doc /* Any radio receiver on Earth: Soviet tracking stations and amateurs around the world. */
		attribute location : String;
		port beaconIn : ~BeaconPort;
	}

	/* =====================================================================
	 * 2. Use case: why the satellite exists
	 * ===================================================================== */

	use case def 'Announce Presence in Orbit' {
		subject sat : Satellite;
		actor rocket : LaunchVehicle;
		actor listeners : GroundStation[1..*];

		objective {
			doc /*
			 * Demonstrate that an artificial satellite has reached orbit, in a way that
			 * anyone with a short-wave receiver can verify, and learn about the upper
			 * atmosphere and ionosphere from the received signal.
			 */
		}
	}

	/* =====================================================================
	 * 3. The mission context: system of interest + environment, connected
	 * ===================================================================== */

	part sputnikMission {
		doc /* The October 1957 mission: rocket, satellite and listeners on the ground. */

		part launcher : LaunchVehicle;
		part satellite :> sputnik1;
		part listeningStations : GroundStation[1..*];

		connect launcher.separationOut to satellite.separationIn;

		interface radioLink : RadioLinkInterface
			connect satellite.beaconOut to listeningStations.beaconIn;

		use case announce : 'Announce Presence in Orbit' {
			subject sat = satellite;
			actor rocket = launcher;
			actor listeners = listeningStations;
		}
	}
}
