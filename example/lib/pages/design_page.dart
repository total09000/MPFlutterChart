// Ported from MPChartExample: design/DesignActivity.kt, with res/layout/activity_design.xml (a ScrollView around a
// vertical LinearLayout with 12dp padding) and res/layout/design_card.xml (one card). The activity's intent extras
// `dark`, `only` and `from` are constructor parameters; main.dart's `/design` route sets them from a deep link.
// DemoBase's status bar hiding is not ported; the body keeps clear of the system bars with a SafeArea,
// as DemoBase's padForWindowInsets does.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart' show ChartHostWidget;

import '../design/android_metrics.dart';
import '../design/design_charts.dart';
import '../design/nightfall.dart';

/// DemoBase's action bar. MPChartExample's AppTheme is `Theme.AppCompat.Light.DarkActionBar` (res/values/styles.xml):
/// the action bar is colorPrimary, `primary_material_dark` #212121, with 4dp elevation and a white 20sp medium title
/// (`TextAppearance.AppCompat.Widget.ActionBar.Title`); its overflow menu is light, white with 16sp items in
/// `primary_text_default_material_light` (87% black) and 16dp side padding. Flutter's automatic back button stays,
/// although DesignActivity shows no up button, because iOS has no system back button.
const Color _actionBarColor = Color(0xFF212121);
const Color _popupTextColor = Color(0xDE000000);

/// The action bar's shadow, fitted to AppCompat's rather than taken from its 4dp elevation.
///
/// Android lights a view's shadow from a point at the top of the screen (the framework's `light_y` 0dp and `light_z`
/// 500dp), right above the action bar, so most of the bar's spot shadow falls under the bar. On the 2.625 emulator the
/// light variant shows #e0e2e4 just below the bar and the stage colour about 13 px further down (C2 finding D6).
///
/// Flutter's AppBar shadow is Material(elevation) → PhysicalShape → `Canvas.drawShadow`. Impeller's drawShadow
/// (engine `impeller/display_list/dl_dispatcher.cc`) has a directional light instead:
/// - the occluder sits z = dpr × elevation device px high;
/// - the bar's shape is moved down by z and blurred with a sigma proportional to z;
/// - the result is filled with 0.25 × the shadow colour's alpha, the tonal colour of a black shadow.
///
/// So the reach and the blur of the shadow grow with the elevation, and its darkness with the alpha.
/// - At elevation 4 with an opaque black the emulator showed #c1c2c4 below the bar and a 28 px reach. That profile fits
///   z = 10.5 px, a sigma of 0.7 z and 0.25 alpha to within half a colour level.
/// - Fitting the same model to Kotlin's profile gives an elevation of 2.25 (z ≈ 5.9 px) and a 40% black: about #e2e4e6
///   below the bar and the stage colour about 14 px down. That is within 5 colour levels of Kotlin's on the first row
///   below the bar and within 3 on every row after it.
///
/// The fit is for Impeller, which the Android build uses. Skia's drawShadow adds an ambient shadow and is not fitted.
const double _actionBarElevation = 2.25;
const Color _actionBarShadowColor = Color(0x66000000);

/// Shows every chart type in the Nightfall design, in its dark or light variant.
class DesignPage extends StatefulWidget {
  /// The [dark] or light variant with the cards [shown] selects for [only] and [from], DesignActivity's extras.
  const DesignPage({
    super.key,
    required this.dark,
    this.only = -1,
    this.from = 0,
  });

  /// The home list's "Dark style" entry, `DesignActivity.intent(this, dark = true)`.
  const DesignPage.darkStyle({super.key}) : dark = true, only = -1, from = 0;

  /// The home list's "Light style" entry, `DesignActivity.intent(this, dark = false)`.
  const DesignPage.lightStyle({super.key}) : dark = false, only = -1, from = 0;

  /// Whether the dark variant is shown, `EXTRA_DARK`.
  final bool dark;

  /// Index of the only card shown, or -1 (or any index outside the cards) for [from] on, `EXTRA_ONLY`.
  final int only;

  /// Index of the first card shown when [only] selects none, `EXTRA_FROM`.
  final int from;

  /// The cards DesignActivity shows: `cards[only]` alone when [only] is an index of [cards], otherwise the cards from
  /// [from] on, with [from] clamped to the indexes of [cards].
  ///
  /// The indexes are those of `DesignCharts.all`, which does not have the combined card yet: 0 to 6 are Kotlin's (3 is
  /// the pie, 6 the radar), and 7 to 9 are Kotlin's 8 to 10 until the combined card is ported.
  static List<T> shown<T>(
    List<T> cards, {
    required int only,
    required int from,
  }) => only >= 0 && only < cards.length
      ? [cards[only]]
      : cards.sublist(from.clamp(0, cards.length - 1));

  @override
  State<DesignPage> createState() => _DesignPageState();
}

class _DesignPageState extends State<DesignPage> {
  /// DesignActivity's `MENU_TOGGLE` item id.
  static const int _menuToggle = 1;

  late final NightfallTheme _theme = widget.dark
      ? Nightfall.dark
      : Nightfall.light;

  /// The density [_cards] were built for.
  double? _devicePixelRatio;

  /// The system font size [_cards] were built for.
  TextScaler? _textScaler;

  /// Built once, as onCreate builds them, so a rebuild keeps the charts. A change of the density or of the system font
  /// size builds them again, as the configuration change recreates the activity on Android, so the pill markers keep to
  /// whole device px and follow the font size.
  late List<DesignCard> _cards;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    if (dpr != _devicePixelRatio || textScaler != _textScaler) {
      _devicePixelRatio = dpr;
      _textScaler = textScaler;
      _cards = DesignPage.shown(
        DesignCharts.all(_theme, devicePixelRatio: dpr, textScaler: textScaler),
        only: widget.only,
        from: widget.from,
      );
    }
  }

  /// onOptionsItemSelected: the toggle opens the other variant in place of this page, keeping [DesignPage.only].
  void _onOptionsItemSelected(int itemId) {
    if (itemId == _menuToggle) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DesignPage(dark: !widget.dark, only: widget.only),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _theme.stage,
    appBar: AppBar(
      title: Text(
        widget.dark ? 'All chart types, dark' : 'All chart types, light',
      ),
      // `?attr/actionBarSize`, 56dp on a phone, which the action bar's layout reads with getDimensionPixelSize, so
      // the bar (and the cards below it) end on a whole device px.
      toolbarHeight: androidDimensionPx(
        kToolbarHeight,
        MediaQuery.devicePixelRatioOf(context),
      ),
      backgroundColor: _actionBarColor,
      foregroundColor: Colors.white,
      elevation: _actionBarElevation,
      scrolledUnderElevation: _actionBarElevation,
      shadowColor: _actionBarShadowColor,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      actions: [
        PopupMenuButton<int>(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          onSelected: _onOptionsItemSelected,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _menuToggle,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(color: _popupTextColor, fontSize: 16),
              ),
              child: Text(widget.dark ? 'Light variant' : 'Dark variant'),
            ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        dragStartBehavior: chartScrollDragStartBehavior,
        // The cards container's android:padding="12dp".
        padding: EdgeInsets.all(
          androidDimensionPx(12, MediaQuery.devicePixelRatioOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final card in _cards) _DesignCardView(card, _theme)],
        ),
      ),
    ),
  );
}

/// design_card.xml filled in as DesignActivity fills it: a card with 18dp corners and a 1px grid stroke, the title
/// and subtitle on the left of the delta pill, and the chart in a 230dp container below them.
///
/// Every dimension is laid out in whole device px as Android lays it out ([androidDimensionPx], [AndroidTextView]),
/// so the card is as tall as on Android: 37 + 96 + 26 + 604 + 37 = 800 px at 2.625, with a 37 px margin below it.
class _DesignCardView extends StatelessWidget {
  const _DesignCardView(this.card, this.theme);

  final DesignCard card;
  final NightfallTheme theme;

  @override
  Widget build(BuildContext context) {
    final delta = card.delta;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    double dp(double value) => androidDimensionPx(value, dpr);
    // The XML TextViews take nothing from Material's text theme (bodyMedium has letter spacing and its own line
    // height): each text sets its weight and colour, and AndroidTextView its size and line box.
    return DefaultTextStyle(
      style: const TextStyle(),
      // android:layout_marginBottom="14dp". Not a Container: it would also inset the content by the border's width,
      // and a GradientDrawable's stroke does not pad the view.
      child: Padding(
        padding: EdgeInsets.only(bottom: dp(14)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.card,
            // Utils.convertDpToPixel(18f), a float that is not rounded to a whole px.
            borderRadius: BorderRadius.circular(18),
            // setStroke(1, grid): one device px inside the card's bounds, which are whole device px.
            border: Border.all(
              color: theme.grid,
              width: 1 / dpr,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          // android:padding="14dp".
          child: Padding(
            padding: EdgeInsets.all(dp(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AndroidTextView(
                            card.title,
                            sp: 15,
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AndroidTextView(
                            card.subtitle,
                            sp: 12,
                            style: TextStyle(color: theme.muted),
                          ),
                        ],
                      ),
                    ),
                    if (delta != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Nightfall.withAlpha(Nightfall.green, 30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: dp(8),
                            vertical: dp(4),
                          ),
                          child: AndroidTextView(
                            delta,
                            sp: 12,
                            style: const TextStyle(
                              color: Nightfall.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: dp(10)),
                  child: SizedBox(
                    height: dp(230),
                    child: ChartHostWidget(
                      chart: card.chart,
                      data: card.chart.data,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
