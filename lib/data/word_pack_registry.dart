import '../models/word_category.dart';
import 'word_packs/abstract_concepts.dart';
import 'word_packs/adult.dart';
import 'word_packs/animals.dart';
import 'word_packs/daily_life.dart';
import 'word_packs/food.dart';
import 'word_packs/games.dart';
import 'word_packs/history.dart';
import 'word_packs/movies.dart';
import 'word_packs/music.dart';
import 'word_packs/nature.dart';
import 'word_packs/objects.dart';
import 'word_packs/people.dart';
import 'word_packs/pers_books.dart';
import 'word_packs/pers_heroes.dart';
import 'word_packs/pers_history.dart';
import 'word_packs/pers_mind.dart';
import 'word_packs/pers_music.dart';
import 'word_packs/pers_russia.dart';
import 'word_packs/pers_science.dart';
import 'word_packs/pers_screen.dart';
import 'word_packs/pers_sport.dart';
import 'word_packs/phrases.dart';
import 'word_packs/place_arch.dart';
import 'word_packs/place_cities.dart';
import 'word_packs/place_countries.dart';
import 'word_packs/place_daily.dart';
import 'word_packs/place_fiction.dart';
import 'word_packs/place_fun.dart';
import 'word_packs/place_landmarks.dart';
import 'word_packs/place_nature.dart';
import 'word_packs/place_odd.dart';
import 'word_packs/place_space.dart';
import 'word_packs/place_transit.dart';
import 'word_packs/places.dart';
import 'word_packs/science.dart';
import 'word_packs/sports.dart';
import 'word_packs/technology.dart';

/// The full bundled word base.
///
/// Guiding rule for every pair: **simple words, hard pairs**. Both words must
/// be instantly understood by any player — difficulty comes from how close and
/// ambiguous the two words are, never from rare or academic vocabulary.
///
/// To extend the base, add a file under `word_packs/` exporting a
/// `const WordCategory` and register it here. `test/word_pack_quality_test.dart`
/// then validates the new pairs automatically: no synonyms, no shared stems,
/// no over-long or academic words, unique, and tagged.

const List<WordCategory> allWordCategories = [
  objectsCategory,
  peopleCategory,
  animalsCategory,
  foodCategory,
  placesCategory,
  technologyCategory,
  natureCategory,
  moviesCategory,
  gamesCategory,
  historyCategory,
  scienceCategory,
  sportsCategory,
  musicCategory,
  dailyLifeCategory,
  abstractCategory,
  phrasesCategory,
  adultCategory,
  persScreenCategory,
  persSportCategory,
  persHistoryCategory,
  persMindCategory,
  persMusicCategory,
  persBooksCategory,
  persHeroesCategory,
  persRussiaCategory,
  persScienceCategory,
  placeCitiesCategory,
  placeCountriesCategory,
  placeNatureCategory,
  placeLandmarksCategory,
  placeArchCategory,
  placeTransitCategory,
  placeOddCategory,
  placeSpaceCategory,
  placeFictionCategory,
  placeFunCategory,
  placeDailyCategory,
];
