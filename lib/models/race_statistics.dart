import '../config/app_config.dart';
import 'gara.dart';

bool isRaceEligibleForStatistics(Gara race) {
  return race.status == RaceStatuses.sicWinOk;
}

List<Gara> eligibleRacesForStatistics(Iterable<Gara> races) {
  return races.where(isRaceEligibleForStatistics).toList(growable: false);
}
