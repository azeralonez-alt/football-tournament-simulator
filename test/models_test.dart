import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_turnamen/models/models.dart';
import 'package:simulator_turnamen/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('localLeagueZoneColor returns expected zone colors', () {
      expect(AppTheme.localLeagueZoneColor(1), AppTheme.zoneChampions);
      expect(AppTheme.localLeagueZoneColor(4), AppTheme.zoneChampions);
      expect(AppTheme.localLeagueZoneColor(5), AppTheme.zoneWinner);
      expect(AppTheme.localLeagueZoneColor(9), AppTheme.zoneFederation);
      expect(AppTheme.localLeagueZoneColor(13), AppTheme.zoneMidRange);
      expect(AppTheme.localLeagueZoneColor(18), AppTheme.zoneChallenger);
      expect(AppTheme.localLeagueZoneColor(20), AppTheme.zoneChallenger);
      expect(AppTheme.localLeagueZoneColor(21), isNull);
    });

    test('ovrColors categorizes OVR tiers accurately', () {
      expect(AppTheme.ovrColors(90).foreground, AppTheme.ovrEliteText);
      expect(AppTheme.ovrColors(80).foreground, AppTheme.ovrMidText);
      expect(AppTheme.ovrColors(70).foreground, AppTheme.ovrLowText);
    });
  });

  group('Data Models JSON serialization', () {
    test('Team toJson and fromJson round-trip', () {
      final team = Team(
        id: 'team_1',
        name: 'Garuda FC',
        leagueId: 'liga_a',
        ovr: 86,
        lastOvrChange: 3,
        seasonOvrStart: 83,
        colorValue: 0xFF00A859,
        trophies: {'local_league': 2, 'champions_league': 1},
        seasonHistory: const [
          TeamSeasonHistory(
            seasonNumber: 1,
            leagueId: 'liga_a',
            leagueName: 'Liga A',
            leagueRank: 1,
            continentalTournamentName: 'Champions League',
            continentalAchievement: 'Juara',
            matchesPlayed: 38,
            goalsFor: 84,
            goalsAgainst: 29,
            ovrStart: 82,
            ovrEnd: 85,
          ),
        ],
      );

      final decoded = Team.fromJson(team.toJson());
      expect(decoded.id, team.id);
      expect(decoded.name, team.name);
      expect(decoded.leagueId, team.leagueId);
      expect(decoded.ovr, 86);
      expect(decoded.lastOvrChange, 3);
      expect(decoded.seasonOvrDelta, 3);
      expect(decoded.totalTrophies, 3);
      expect(decoded.initials, 'GFC');
      expect(decoded.seasonHistory.length, 1);
      expect(decoded.lastSeasonAvgGoalsFor, closeTo(84 / 38, 0.0001));
    });

    test('Tournament toJson and fromJson round-trip', () {
      const tournament = Tournament(
        id: 'ucl_s2',
        name: 'Champions League',
        type: TournamentType.continentalLeague,
        seasonNumber: 2,
        tier: 1,
        teamIds: ['team_1', 'team_2'],
        potsOrGroups: {
          'Pot 1': ['team_1'],
          'Pot 2': ['team_2'],
        },
        isActive: true,
        currentStage: 'League Phase',
      );

      final decoded = Tournament.fromJson(tournament.toJson());
      expect(decoded.id, tournament.id);
      expect(decoded.type, TournamentType.continentalLeague);
      expect(decoded.isContinental, isTrue);
      expect(decoded.potsOrGroups['Pot 1'], ['team_1']);
    });

    test('MatchGame toJson and fromJson round-trip', () {
      const match = MatchGame(
        id: 'm_1',
        tournamentId: 'cup_a_s1',
        tournamentName: 'Cup Liga A',
        seasonNumber: 1,
        gameweek: 10,
        stageName: 'Final',
        leg: 1,
        isKnockout: true,
        isNeutralVenue: true,
        homeTeamId: 'team_1',
        awayTeamId: 'team_2',
        homeScore: 3,
        awayScore: 3,
        homePenaltyScore: 5,
        awayPenaltyScore: 4,
        isFinished: true,
        isChaoticMatch: true,
      );

      final decoded = MatchGame.fromJson(match.toJson());
      expect(decoded.id, 'm_1');
      expect(decoded.hasPenaltyShootout, isTrue);
      expect(decoded.winnerTeamId, 'team_1');
      expect(decoded.totalGoals, 6);
      expect(decoded.isChaoticMatch, isTrue);
    });

    test('StandingRow toJson and fromJson round-trip', () {
      const row = StandingRow(
        teamId: 'team_1',
        tournamentId: 'liga_a_s1',
        position: 1,
        played: 10,
        won: 8,
        drawn: 1,
        lost: 1,
        goalsFor: 24,
        goalsAgainst: 8,
        points: 25,
        form: ['W', 'W', 'D', 'W', 'W'],
      );

      final decoded = StandingRow.fromJson(row.toJson());
      expect(decoded.goalDifference, 16);
      expect(decoded.points, 25);
      expect(decoded.form, ['W', 'W', 'D', 'W', 'W']);
    });

    test('NewsEvent and SeasonArchive toJson and fromJson round-trip', () {
      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final event = NewsEvent(
        id: 'ev_1',
        seasonNumber: 1,
        gameweek: 19,
        type: NewsEventType.transferWindow,
        title: 'Golden Era!',
        description: 'Garuda FC naik +8 OVR',
        teamId: 'team_1',
        ovrDelta: 8,
        timestamp: now,
      );

      final archive = SeasonArchive(
        seasonNumber: 1,
        championsMap: const {
          'liga_a_s1': TournamentChampionEntry(
            tournamentId: 'liga_a_s1',
            tournamentName: 'Liga A',
            tournamentType: TournamentType.localLeague,
            championTeamId: 'team_1',
            championTeamName: 'Garuda FC',
            runnerUpTeamId: 'team_2',
            runnerUpTeamName: 'Elang United',
          ),
        },
        topScoringTeam: const TeamStatRecord(
          teamId: 'team_1',
          teamName: 'Garuda FC',
          tournamentName: 'Liga A',
          value: 84,
          label: '84 Gol',
        ),
        bestDefenseTeam: const TeamStatRecord(
          teamId: 'team_1',
          teamName: 'Garuda FC',
          tournamentName: 'Liga A',
          value: 29,
          label: '29 Kebobolan',
        ),
        newsEvents: [event],
        archivedAt: now,
      );

      final decoded = SeasonArchive.fromJson(archive.toJson());
      expect(decoded.seasonNumber, 1);
      expect(decoded.championsList.length, 1);
      expect(decoded.topScoringTeam?.value, 84);
      expect(decoded.newsEvents.first.type, NewsEventType.transferWindow);
      expect(decoded.archivedAt, now);
    });
  });
}
