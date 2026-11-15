# MaynardGolf — App Specification

Exhaustive Cucumber-style acceptance tests documenting every screen, interaction, and business rule.

---

## Feature: Main View — Home Screen

```gherkin
Feature: Main View
  As a golfer
  I want to see my recent activity at a glance
  So that I can quickly resume or review rounds

  Background:
    Given the app is launched
    And the SwiftData container is initialized with Player and Round models

  # --- Loading State ---

  Scenario: App displays loading spinner while fetching data
    Given data has not yet been fetched
    When the Main View appears
    Then a centered ProgressView spinner is displayed

  # --- No Data State ---

  Scenario: Empty state shown when no players exist
    Given there are no players in the database
    When the Main View finishes loading
    Then the "Welcome" empty state is displayed
    And a golf circle icon is shown
    And the description reads "Data will appear here as you play."
    And a "Start a Round" button is displayed with borderedProminent style

  Scenario: Starting a round from empty state
    Given the empty state is displayed
    When the user taps "Start a Round"
    Then the New Game View is presented

  # --- Ready State: In Progress Rounds ---

  Scenario: In-progress rounds section is visible
    Given there is a round created today with unscored holes
    When the Main View finishes loading
    Then the "In Progress" section header is displayed in orange
    And the in-progress round is shown as a RoundCellView

  Scenario: In-progress rounds section is hidden when none exist
    Given there are no rounds created today with unscored holes
    When the Main View finishes loading
    Then the "In Progress" section is not displayed

  Scenario: Tapping an in-progress round opens its detail
    Given there is an in-progress round displayed
    When the user taps the in-progress round cell
    Then the app navigates to the Round Detail View for that round

  # --- Ready State: Recent Players ---

  Scenario: Recent players section shows up to 3 players
    Given there are 5 players in the database
    When the Main View finishes loading
    Then the "Recent Players" section is displayed
    And at most 3 players are shown sorted by last name
    And each player is displayed as a PlayerTileView

  Scenario: Recent players section shows "All Players" button
    Given there are players in the database
    When the Main View finishes loading
    Then an "All Players" button is displayed in the Recent Players header

  Scenario: Tapping "All Players" navigates to Players View
    Given the "All Players" button is visible
    When the user taps "All Players"
    Then the app navigates to the Players View

  Scenario: Tapping a player tile navigates to Player Detail
    Given a player tile is displayed in Recent Players
    When the user taps the player tile
    Then the app navigates to the Player Detail View for that player

  # --- Ready State: Recent Rounds ---

  Scenario: Recent rounds section shows up to 10 rounds
    Given there are 15 non-deleted completed rounds
    When the Main View finishes loading
    Then the "Recent Rounds" section is displayed
    And at most 10 rounds are shown sorted newest first
    And each round is displayed as a RoundCellView

  Scenario: Deleted rounds are excluded from recent rounds
    Given there is a round with deleted flag set to true
    When the Main View finishes loading
    Then that round is not displayed in the Recent Rounds section

  Scenario: Tapping "All Rounds" navigates to Rounds View
    Given the "All Rounds" button is visible
    When the user taps "All Rounds"
    Then the app navigates to the Rounds View

  Scenario: Tapping a round cell navigates to Round Detail
    Given a round cell is displayed in Recent Rounds
    When the user taps the round cell
    Then the app navigates to the Round Detail View for that round

  # --- Toolbar ---

  Scenario: Settings button opens Settings View
    Given the Main View is displayed
    When the user taps the gear icon in the toolbar
    Then the Settings View is presented as a full-screen cover

  Scenario: New Round button opens New Game View
    Given the Main View is displayed
    When the user taps the "New Round" button in the toolbar
    Then the New Game View is presented

  # --- Scroll Behavior ---

  Scenario: Toolbar icons are white when not scrolled
    Given the Main View is displayed
    And the user has not scrolled past the header image
    Then the toolbar icons (gear and new round) are white

  Scenario: Toolbar icons turn blue when scrolled past header
    Given the Main View is displayed
    When the user scrolls past the header image
    Then the toolbar icons (gear and new round) turn blue

  # --- Header ---

  Scenario: Header displays app branding
    Given the Main View is displayed
    Then the header background image is shown
    And the title "Maynard Golf" is overlaid in white largeTitle font

  # --- Refresh ---

  Scenario: Data refreshes after import notification
    Given the Main View is displayed
    When a didImport notification is posted
    Then the Main View refreshes its data

  Scenario: Data refreshes on appear
    Given the Main View is about to appear
    When the view triggers onAppear
    Then the model calls refresh()
```

---

## Feature: New Game — Round Creation

```gherkin
Feature: New Game View
  As a golfer
  I want to create a new round with selected players and tees
  So that I can start scoring

  Background:
    Given the New Game View is presented

  # --- Title ---

  Scenario: New round title is displayed
    Then the title "New Round" is shown in largeTitle font

  # --- Player List ---

  Scenario: Selected players are listed with their tees
    Given 2 players have been added to the round
    Then 2 player cells are displayed
    And each cell shows the player name and selected tee

  Scenario: Swipe to remove a player
    Given 2 players have been added
    When the user swipes left on a player cell
    And confirms the delete action
    Then the player is removed from the round

  Scenario: Maximum 4 players enforced
    Given 4 players have been added to the round
    Then the "+" add player button is not visible

  Scenario: Add player button visible when under max
    Given fewer than 4 players have been added
    Then the "+" add player button is visible as a blue plus circle icon

  # --- Add Player ---

  Scenario: Add player button navigates to Player Chooser
    Given the "+" button is visible
    When the user taps the "+" button
    Then the Player Chooser View is presented

  # --- Tee Change ---

  Scenario: Tapping tee button opens Tee Selector
    Given a player is listed
    When the user taps the tee "Change" button on that player's cell
    Then the Tee Selector View is presented as a medium-detent sheet
    And the sheet header shows the player's name

  Scenario: Tee change updates the player's tee
    Given the Tee Selector sheet is open for a player
    When the user selects "Blue" tee
    Then the player's tee is updated to Blue
    And the sheet is dismissed

  # --- Quick Add ---

  Scenario: Quick Add shows recent players not already selected
    Given there are 5 players in the database
    And 2 are already selected for the round
    Then the Quick Add section shows the other 3 players in a grid
    And each shows a circular avatar and first name

  Scenario: Quick Add is hidden when no unselected players exist
    Given all players in the database are already selected
    Then the Quick Add section is not displayed

  Scenario: Tapping a quick-add player adds them with white tee
    Given a player appears in the Quick Add grid
    When the user taps that player's avatar
    Then the player is added to the round with white tee selected
    And the addition animates in

  # --- Start Game ---

  Scenario: Start Game button hidden when no players selected
    Given no players have been added to the round
    Then the "Start Game" button is not visible

  Scenario: Start Game button visible with at least 1 player
    Given 1 or more players have been added
    Then the "Start Game" button is visible with borderedProminent style

  Scenario: Starting a game creates a round and opens hole entry
    Given 2 players are selected with their tees
    When the user taps "Start Game"
    Then a new Round is created in SwiftData
    And the round contains 9 holes from MaynardGC course data
    And each player's scores are initialized to nil for all holes
    And the round date is set to the current time
    And the New Game View is dismissed
    And the Hole View Container is presented as a full-screen cover

  # --- Course ---

  Scenario: Round is always created for MaynardGC front 9
    When a round is created
    Then the courseID is "MaynardGC"
    And only the front 9 holes (1-9) are included
```

---

## Feature: Tee Selector

```gherkin
Feature: Tee Selector
  As a golfer
  I want to choose which tees I'm playing from
  So that correct yardages are tracked

  Background:
    Given the Tee Selector sheet is presented for a player

  Scenario: Header shows player name
    Then the header reads "Choose Tees for {player name}" in bold

  Scenario: Four tee options displayed as colored circles
    Then 4 tee buttons are displayed in a 2×2 grid
    And each button is an 80×80pt circle
    And the "Blue" button has a blue background with white text
    And the "White" button has a white background with black text and black stroke
    And the "Yellow" button has a yellow background with white text
    And the "Red" button has a red background with white text

  Scenario Outline: Selecting a tee updates binding and dismisses
    When the user taps the "<tee>" button
    Then the player's tee is set to <tee_value>
    And the sheet is dismissed

    Examples:
      | tee    | tee_value |
      | Blue   | .blue     |
      | White  | .white    |
      | Yellow | .yellow   |
      | Red    | .red      |
```

---

## Feature: Player Chooser

```gherkin
Feature: Player Chooser
  As a golfer creating a round
  I want to select which players will play
  So that I can set up the scorecard

  # --- Empty State ---

  Scenario: No players exist in database
    Given there are no players in the database
    When the Player Chooser View is presented
    Then a "No Players Yet" empty state is displayed with a person.circle icon
    And an "Add One" button is shown

  Scenario: Add One button opens Player Entry
    Given the empty state is shown
    When the user taps "Add One"
    Then the Player Entry View is presented as a full-screen cover in create mode

  # --- Player List ---

  Scenario: All available players are listed
    Given there are 5 players in the database
    When the Player Chooser View is presented
    Then all 5 players are listed with their names

  Scenario: Tapping a player toggles selection on
    Given a player is not selected
    When the user taps that player's row
    Then a checkmark appears next to the player's name
    And the player is added to the selection set

  Scenario: Tapping a selected player toggles selection off
    Given a player is selected (has checkmark)
    When the user taps that player's row
    Then the checkmark disappears
    And the player is removed from the selection set

  Scenario: Add New Player button at bottom of list
    Given the player list is displayed
    Then an "Add New Player" button is shown at the bottom of the list

  Scenario: Add New Player opens Player Entry
    When the user taps "Add New Player"
    Then the Player Entry View is presented as a full-screen cover in create mode

  # --- Done ---

  Scenario: Done button returns selected players with white tee default
    Given 3 players are selected
    When the user taps "Done" in the toolbar
    Then the handler is called with 3 AddPlayerModel objects
    And each has tee set to white
    And the Player Chooser is dismissed
```

---

## Feature: Player Entry — Add/Edit Player

```gherkin
Feature: Player Entry
  As a golfer
  I want to create and edit player profiles
  So that I can track individual stats and scores

  Background:
    Given the Player Entry View is presented

  # --- Create Mode ---

  Scenario: Create mode shows empty form
    Given the view is in create mode (no existing player)
    Then the title is "Create Player"
    And the First Name field is empty
    And the Last Name field is empty
    And the color selection defaults to blue
    And the action button reads "Create"

  Scenario: Create button is disabled with empty names
    Given the First Name field is empty
    Or the Last Name field is empty
    Then the "Create" button is disabled (shouldDenyEntry is true)

  Scenario: Creating a player with valid data
    Given the user enters "John" as First Name
    And the user enters "Doe" as Last Name
    And selects green as the player color
    When the user taps "Create"
    Then a new Player is inserted into SwiftData
    And the player's color is set to green
    And the view is dismissed

  Scenario: Duplicate name prevention on create
    Given a player named "John Doe" already exists (case-insensitive)
    And the user enters "john" and "doe" in the name fields
    When the user taps "Create"
    Then a red error message is displayed indicating the name already exists
    And no player is created

  # --- Edit Mode ---

  Scenario: Edit mode pre-fills existing data
    Given the view is in edit mode for player "Jane Smith" with color red
    Then the First Name field contains "Jane"
    And the Last Name field contains "Smith"
    And the color red is selected
    And the action button reads "Save"
    And the existing player photo is displayed

  Scenario: Saving edits to an existing player
    Given the view is in edit mode
    And the user changes the First Name to "Janet"
    When the user taps "Save"
    Then the player's first name is updated to "Janet" in SwiftData
    And the view is dismissed

  Scenario: Duplicate name prevention on edit
    Given another player "Bob Jones" exists
    And the user renames the current player to "Bob Jones"
    When the user taps "Save"
    Then a red error message is displayed
    And the changes are not saved

  # --- Photo Selection ---

  Scenario: Select Photo opens PhotosPicker
    When the user taps "Select Photo"
    Then the system PhotosPicker is presented
    And it filters to images only (no screenshots)

  Scenario: Selecting a photo shows it and navigates to cropper
    Given the PhotosPicker is open
    When the user selects a photo
    Then the photo is loaded and displayed in the circular preview
    And the app navigates to the Photo Cropper view
    And the scale resets to 1.0 and offset resets to zero

  Scenario: Adjust button navigates to Photo Cropper
    Given a photo has been selected
    When the user taps "Adjust"
    Then the Photo Cropper view is presented

  # --- Color Picker ---

  Scenario: Five color options displayed
    Then 5 color circles are shown: red, blue, green, yellow, orange

  Scenario: Selected color shows concentric circles effect
    Given the current color is blue
    Then the blue circle shows a concentric circles visual
    And the other 4 circles show solid fills

  Scenario: Tapping a color selects it
    Given the current color is blue
    When the user taps the green circle
    Then green becomes the selected color
    And the green circle shows concentric circles
    And the blue circle reverts to solid

  # --- Cancel ---

  Scenario: Cancel dismisses without saving
    Given the user has entered data
    When the user taps "Cancel" in the toolbar
    Then the view is dismissed
    And no changes are persisted

  Scenario: Interactive dismiss is disabled
    Given the Player Entry View is presented as a sheet
    Then swiping down to dismiss is disabled
    And the user must use Cancel or Save/Create

  # --- Photo Storage ---

  Scenario: Photo saved as PNG in documents/pics
    Given the user has selected and cropped a photo
    When the player is saved
    Then the photo is saved as PNG in the Documents/pics/ directory
    And the player's photoPath is set to the relative path
    And the ImageCache is cleared for that player if editing
```

---

## Feature: Photo Cropper

```gherkin
Feature: Photo Cropper
  As a golfer
  I want to crop and position my avatar photo
  So that it displays nicely in the app

  Background:
    Given the Photo Cropper is presented with a selected image

  Scenario: Circular crop mask displayed
    Then a circular mask of 240pt diameter is shown
    And the image is visible only within the circle
    And the area outside the circle is darkened

  Scenario: Navigation title shown
    Then the navigation title reads "Size your picture"

  Scenario: Pinch to zoom scales the image
    When the user performs a pinch-to-zoom gesture
    Then the image scales proportionally within the crop circle
    And the scale value is updated

  Scenario: Pinch gesture end commits scale
    When the user ends a pinch gesture
    Then the final scale is persisted to the binding
    And the gesture amount resets to zero

  Scenario: Drag gesture pans the image
    When the user drags the image
    Then the image moves within the crop circle
    And the offset is calculated as translation / 2.0

  Scenario: Navigating back preserves crop settings
    Given the user has zoomed and panned
    When the user navigates back
    Then the scale and offset bindings retain the adjusted values
```

---

## Feature: Hole View Container — 9-Hole Flow

```gherkin
Feature: Hole View Container
  As a golfer playing a round
  I want to navigate through 9 holes entering scores
  So that I can complete my round

  Background:
    Given a round has been created with players
    And the Hole View Container is presented as a full-screen cover

  # --- Navigation ---

  Scenario: TabView displays holes 1 through 9
    Then 9 hole pages are available in a paged TabView
    And page indicators are hidden

  Scenario: Initial hole is the first unscored hole
    Given holes 1-3 have scores and holes 4-9 do not
    When the container appears
    Then hole 4 is the initially selected page

  Scenario: Initial hole is 1 when no holes are scored
    Given no holes have scores
    When the container appears
    Then hole 1 is the initially selected page

  Scenario: Swipe left advances to next hole
    Given hole 3 is currently displayed
    When the user swipes left
    Then hole 4 is displayed

  Scenario: Swipe right goes to previous hole
    Given hole 5 is currently displayed
    When the user swipes right
    Then hole 4 is displayed

  # --- Toolbar ---

  Scenario: Exit button dismisses hole entry
    When the user taps "Exit" in the navigation bar
    Then the Hole View Container is dismissed

  Scenario: Flag button opens Yardage Finder
    When the user taps the flag icon in the toolbar
    Then the Yardage Finder Container View is presented as a medium-detent sheet

  Scenario: Card button opens scorecard
    When the user taps "Card" in the toolbar
    Then the Vertical Card View is presented as a medium-detent sheet

  # --- Round Completion ---

  Scenario: All holes scored triggers completion
    Given holes 1-8 have scores
    When the user enters a score for hole 9
    And all players have scores for all 9 holes
    Then the TabView jumps to hole 9
    And the Round Complete View is presented as a medium-detent sheet

  Scenario: Partial scores do not trigger completion
    Given holes 1-7 have scores for all players
    And hole 8 has scores for only some players
    Then the Round Complete View is not presented
```

---

## Feature: Hole View — Single Hole Scoring

```gherkin
Feature: Hole View
  As a golfer on a specific hole
  I want to see hole info and enter scores for each player
  So that I can record the round accurately

  Background:
    Given the Hole View is displayed for a specific hole

  # --- Header ---

  Scenario: Hole icon displayed
    Then the hole icon image is shown on the left (max height 530pt)

  Scenario: Hole number displayed in circle
    Then the hole number is displayed in a 120×120pt circle
    And the number is in 64pt bold green font
    And "HOLE" label appears below the number

  Scenario: Par value displayed
    Then the par is shown in an 80×80pt green circle
    With "PAR" label and par number in white

  Scenario: Handicap value displayed
    Then the handicap is shown in a 60×60pt green circle
    With "HC" label and handicap number in white

  Scenario: Yardage display shows all 4 tee distances
    Then 4 yardage boxes are stacked vertically
    And the blue box shows blue tee yardage
    And the gray box shows white tee yardage
    And the yellow box shows yellow tee yardage
    And the red box shows red tee yardage

  # --- Score Area ---

  Scenario: All players listed with score status
    Given the round has 3 players
    Then 3 player rows are displayed in the score area
    And each row shows the player name in largeTitle font
    And each row shows the running over/under on the left

  Scenario: Unscored player shows plus button
    Given a player has not entered a score for this hole
    Then a "+" circle icon is shown as the score button

  Scenario: Scored player shows their score
    Given a player scored 4 on this hole
    Then the number "4" is shown as the score button

  Scenario: Zero score displays as dash
    Given a player has a score of 0
    Then "-" is displayed as the score

  Scenario: Tapping score button opens Entry View
    When the user taps a player's score button
    Then the Entry View sheet is presented at medium detent
    And it is configured for that player and hole

  Scenario: Score area has material background
    Then the score area has an ultraThinMaterial background
    And a corner radius of 20pt
```

---

## Feature: Entry View — Score Input

```gherkin
Feature: Entry View
  As a golfer
  I want to quickly enter a score for a hole
  So that scoring is fast during play

  Background:
    Given the Entry View is presented for a player on a specific hole

  # --- Button Mode (Default) ---

  Scenario: Title displays player name and hole
    Then the title reads "Enter {name}'s score on hole {number}"
    And the title is in green color

  Scenario: Quick entry grid shows scores 2-7
    Then a grid of 6 circular buttons is displayed
    And the buttons show scores: 2, 3, 4, 5, 6, 7
    And each button is 80×80pt with white text on green background

  Scenario: Delete button shown in grid
    Then a backspace icon button is displayed in the grid

  Scenario: Zero button shown as dash
    Then a "-" button is displayed in the grid for score 0

  Scenario: Plus button toggles to stepper mode
    Then a "+" button is displayed in the grid
    When the user taps "+"
    Then the view animates to Stepper mode

  Scenario Outline: Tapping a quick score button enters the score
    When the user taps the "<score>" button
    Then the score <score> is saved for the player on this hole
    And the round data is updated in SwiftData
    And a refreshListener notification is posted

    Examples:
      | score |
      | 2     |
      | 3     |
      | 4     |
      | 5     |
      | 6     |
      | 7     |

  Scenario: Tapping delete clears the score
    When the user taps the delete (backspace) button
    Then the player's score for this hole is set to nil

  Scenario: Tapping dash enters zero
    When the user taps the "-" button
    Then the score 0 is saved (displayed as "-")

  # --- Stepper Mode ---

  Scenario: Stepper mode initial value
    Given the view is in stepper mode
    Then the initial score value is 7
    And the score is displayed in large green text

  Scenario: Plus button increments score
    Given the stepper shows score 7
    When the user taps the plus button
    Then the score changes to 8

  Scenario: Minus button decrements score
    Given the stepper shows score 7
    When the user taps the minus button
    Then the score changes to 6

  Scenario: Score cannot go below 1
    Given the stepper shows score 1
    When the user taps the minus button
    Then the score remains 1

  Scenario: Score cannot exceed 25
    Given the stepper shows score 25
    When the user taps the plus button
    Then the score remains 25

  Scenario: Cancel returns to button mode
    Given the stepper is displayed
    When the user taps "Cancel"
    Then the view animates back to button mode
    And no score is entered

  Scenario: Done submits the stepper score
    Given the stepper shows score 10
    When the user taps "Done"
    Then the score 10 is saved for the player on this hole
```

---

## Feature: Yardage Finder — GPS Distance

```gherkin
Feature: Yardage Finder
  As a golfer on the course
  I want to know my distance to the green
  So that I can select the right club

  # --- Authorization ---

  Scenario: Location not authorized shows unavailable view
    Given location services are not authorized
    When the Yardage Finder is presented
    Then a ContentUnavailableView is shown
    And a button to open Settings is displayed

  Scenario: Location authorized shows distances
    Given location services are authorized
    When the Yardage Finder is presented
    Then distances to the green are calculated and displayed

  # --- Distance Display ---

  Scenario: Title shows hole number with ordinal suffix
    Given the current hole is hole 3
    Then the title reads "3rd Green"

  Scenario Outline: Ordinal suffixes are correct
    Given the current hole is hole <number>
    Then the title reads "<ordinal> Green"

    Examples:
      | number | ordinal |
      | 1      | 1st     |
      | 2      | 2nd     |
      | 3      | 3rd     |
      | 4      | 4th     |
      | 9      | 9th     |

  Scenario: Three distances displayed
    Then the "Front" distance is shown in yards
    And the "Center" distance is shown in yards
    And the "Back" distance is shown in yards
    And each distance is in title2 bold font

  # --- Accuracy Indicator ---

  Scenario Outline: Accuracy color based on GPS precision
    Given the GPS accuracy is <accuracy> yards
    Then the accuracy indicator color is <color>

    Examples:
      | accuracy | color  |
      | 3        | green  |
      | 6        | yellow |
      | 9        | orange |
      | 15       | red    |

  Scenario: Accuracy value displayed
    Given the GPS accuracy is 4 yards
    Then the text "± 4" is displayed in green

  # --- Close ---

  Scenario: Close button dismisses the view
    When the user taps the close (xmark.circle) button
    Then the Yardage Finder sheet is dismissed
```

---

## Feature: Round Complete

```gherkin
Feature: Round Complete
  As a golfer who has finished all 9 holes
  I want to see my final scorecard
  So that I can review my round

  Background:
    Given all 9 holes have been scored for all players
    And the Round Complete View is presented

  Scenario: Completion header displayed
    Then the header shows a close button (xmark.circle)
    And the title reads "⛳️ Round Complete"

  Scenario: Final scorecard is embedded
    Then the Vertical Card View is displayed with final scores

  Scenario: Close button dismisses the view
    When the user taps the close button
    Then the Round Complete sheet is dismissed
```

---

## Feature: Round Detail View

```gherkin
Feature: Round Detail View
  As a golfer
  I want to view the full details of a completed round
  So that I can review scores and share results

  Background:
    Given a round exists in the database
    And the Round Detail View is presented for that round

  # --- Header ---

  Scenario: Course name displayed
    Then the course name is shown in title2 font

  Scenario: Date and time displayed
    Then the round date is shown in long format
    And the round time is shown in "h:mm a" format
    And both are in callout gray font

  Scenario: Weather displayed when available
    Given the round has weather data
    Then the weather icon and temperature are displayed

  Scenario: Weather hidden when not available
    Given the round has no weather data
    Then no weather information is shown

  # --- Scorecard ---

  Scenario: Scorecard section shows vertical card
    Then the "Score Card" section is visible
    And a Vertical Card View displays the round's scores

  # --- Players Section ---

  Scenario: Players listed with scores
    Given the round has 3 players
    Then 3 CardPlayerScoreCell rows are displayed
    And each shows: player image, name, total score, to-par string

  Scenario: Player trend arrow when round is complete
    Given the round is marked as complete
    And a player's score is below their 5-round average
    Then a green down-arrow is shown for that player

  Scenario: Player trend arrow for declining performance
    Given the round is marked as complete
    And a player's score is above their 5-round average
    Then a red up-arrow is shown for that player

  Scenario: No trend arrow for incomplete round
    Given the round is not marked as complete
    Then no trend arrows are displayed

  # --- Edit ---

  Scenario: Edit button opens hole entry for editing
    When the user taps "Edit" in the toolbar
    Then the Hole View Container is presented as a full-screen cover
    And the round can be edited

  # --- Share / PDF Export ---

  Scenario: Share button exports PDF
    When the user taps the Share button in the toolbar
    Then a PDF is rendered with:
      | Element       | Content                        |
      | Header        | "Maynard Golf Club"            |
      | Date          | Round date in caption font      |
      | Body          | CardView scorecard              |
    And the PDF is saved to temp directory as "maynardGolf_YYYY-MM-DD.pdf"
    And the system share sheet is presented

  # --- Error ---

  Scenario: Error state on invalid round data
    Given the round has invalid course data
    Then the text "Error" is displayed
```

---

## Feature: Rounds View — All Rounds List

```gherkin
Feature: Rounds View
  As a golfer
  I want to browse all my past rounds
  So that I can find and review specific rounds

  Background:
    Given the Rounds View is presented

  # --- List ---

  Scenario: All non-deleted rounds displayed newest first
    Given there are 20 non-deleted rounds
    Then all 20 rounds are listed
    And they are sorted by date descending (newest first)

  Scenario: Deleted rounds are excluded
    Given there are rounds with deleted flag true
    Then those rounds are not shown in the list

  Scenario: Each round shown as RoundCellView
    Then each round displays:
      | Element      | Description                                |
      | Date         | Callout font, thin weight, left             |
      | Time         | Callout font, thin weight, right            |
      | Player names | Callout, semibold, in player color          |
      | Over/under   | Callout, regular weight, per player         |
      | Separators   | Vertical gray lines between players         |
      | Weather      | Weather icon if available, right side        |

  Scenario: Tapping a round navigates to detail
    When the user taps a round cell
    Then the app navigates to the Round Detail View for that round

  # --- Search ---

  Scenario: Search bar is displayed
    Then a searchable text field is shown

  Scenario: Searching filters by player name
    Given the user types "John" in the search field
    Then only rounds containing a player whose name includes "John" (case-insensitive) are shown

  Scenario: Empty search shows all rounds
    Given the search field is empty
    Then all non-deleted rounds are displayed

  # --- Swipe to Delete ---

  Scenario: Swiping left on a round soft-deletes it
    When the user swipes left on a round cell
    And confirms the delete action
    Then the round's deleted flag is set to true
    And it disappears from the list
    And the context is saved

  # --- Trash Navigation ---

  Scenario: Deleted button navigates to trash
    When the user taps the "Deleted" button in the toolbar
    Then the app navigates to the Delete Round View
```

---

## Feature: Delete Round View — Trash

```gherkin
Feature: Delete Round View (Trash)
  As a golfer
  I want to manage deleted rounds
  So that I can restore accidentally deleted rounds or permanently remove them

  Background:
    Given the Delete Round View is presented

  # --- Empty State ---

  Scenario: Empty trash displays message
    Given there are no soft-deleted rounds
    Then a "No Deleted Rounds" empty state is shown
    And a trash icon is displayed
    And the description reads "Deleted rounds will appear here."

  # --- List ---

  Scenario: Soft-deleted rounds are listed
    Given there are 3 soft-deleted rounds
    Then all 3 rounds are listed as RoundCellView
    And they are sorted by date descending

  Scenario: Navigation title shows "Trash"
    Then the navigation title is "Trash"

  # --- Swipe Actions ---

  Scenario: Swipe to restore a round
    When the user swipes on a deleted round
    And taps the "Restore" button (green)
    Then the round's deleted flag is set to false
    And the round disappears from the trash list
    And the round reappears in the main rounds list

  Scenario: Swipe to permanently delete a round
    When the user swipes on a deleted round
    And taps the "Delete" button (red, destructive)
    Then the round is permanently removed from SwiftData
    And it cannot be recovered

  # --- Bulk Delete ---

  Scenario: Trash toolbar button visible when rounds exist
    Given there are deleted rounds in the trash
    Then the "Trash" button is visible in the toolbar

  Scenario: Trash toolbar button hidden when empty
    Given there are no deleted rounds
    Then the "Trash" toolbar button is not visible

  Scenario: Bulk delete confirmation dialog
    When the user taps the "Trash" toolbar button
    Then a confirmation alert appears
    And the title reads "Permenantly Delete?"
    And the message reads "This will empty your trash."
    And a destructive "Delete" option is shown
    And a "Cancel" option is shown

  Scenario: Confirming bulk delete empties trash
    Given the confirmation dialog is shown
    When the user taps "Delete"
    Then all soft-deleted rounds are permanently removed
    And the trash list is empty

  Scenario: Cancelling bulk delete preserves rounds
    Given the confirmation dialog is shown
    When the user taps "Cancel"
    Then no rounds are deleted
    And the dialog is dismissed
```

---

## Feature: Players View — All Players List

```gherkin
Feature: Players View
  As a golfer
  I want to browse all registered players
  So that I can view their profiles and manage the player list

  Background:
    Given the Players View is presented

  # --- List ---

  Scenario: All players displayed as tile views
    Given there are 5 players
    Then 5 PlayerTileView tiles are displayed in a list

  Scenario: Navigation title shows "Players"
    Then the navigation title is "Players"

  Scenario: Player tile shows avatar, name, and handicap
    Given a player "John Doe" with handicap 15.3 and blue color
    Then the tile shows:
      | Element   | Content                              |
      | Avatar    | Circular photo with blue border       |
      | Name      | "John Doe" in title2 font             |
      | Handicap  | "15.3" with label in right alignment  |

  Scenario: Player tile without handicap
    Given a player with fewer than 8 completed rounds
    Then the handicap section is not shown on the tile

  Scenario: Player tile styling
    Then each tile has systemGray6 background at 0.14 opacity
    And a corner radius of 20pt
    And a gray shadow

  # --- Search ---

  Scenario: Search filters players by name
    Given the user types "Doe" in the search field
    Then only players whose name contains "Doe" (case-insensitive) are shown

  # --- Navigation ---

  Scenario: Tapping a player navigates to detail
    When the user taps a player tile
    Then the app navigates to the Player Detail View for that player

  # --- Add Player ---

  Scenario: Add button opens Player Entry
    When the user taps the "Add" button in the toolbar
    Then the Player Entry View is presented as a full-screen cover in create mode

  # --- Delete Player ---

  Scenario: Swipe to delete shows confirmation
    When the user swipes left on a player tile
    Then a delete confirmation dialog appears

  Scenario: Confirming delete removes the player
    Given the delete confirmation dialog is shown
    When the user taps the destructive "Delete" button
    Then the player is permanently removed from SwiftData
    And all associated PersonRound records are cascade-deleted

  Scenario: Cancelling delete preserves the player
    Given the delete confirmation dialog is shown
    When the user taps "Cancel"
    Then the player is not deleted
```

---

## Feature: Player Detail View

```gherkin
Feature: Player Detail View
  As a golfer
  I want to see detailed statistics for a player
  So that I can track performance trends

  Background:
    Given the Player Detail View is presented for a player with completed rounds

  # --- Header ---

  Scenario: Player avatar displayed large
    Then the player's photo is shown at 100pt radius with colored border

  Scenario: Player name displayed
    Then the player's full name is shown in largeTitle font

  Scenario: Handicap displayed when available
    Given the player has at least 8 completed rounds
    Then the handicap is shown formatted to 1 decimal place

  Scenario: Handicap hidden when insufficient rounds
    Given the player has fewer than 8 completed rounds
    Then the handicap is not displayed

  # --- Score Graph ---

  Scenario: Score trend line chart displayed
    Given the player has score history
    Then a line chart is shown with 100pt height
    And scores are plotted chronologically

  Scenario: Best score annotated on graph
    Then the lowest score is marked with a green point
    And an annotation below shows "score on MM/dd"

  Scenario: Worst score annotated on graph
    Then the highest score is marked with a red point
    And an annotation above shows "score on MM/dd"

  Scenario: Average line shown on graph
    Then a dashed horizontal line is drawn at the average score

  # --- Stats Cards ---

  Scenario: Best, worst, and average stats displayed
    Then three stat values are shown:
      | Stat    | Color |
      | Best    | green |
      | Worst   | red   |
      | Average | gray  |

  # --- Score Distribution ---

  Scenario: Side histogram shows score type distribution
    Then a horizontal bar chart is displayed (max height 90pt)
    And bars are colored by score type:
      | Score Type     | Color  |
      | Double Eagle   | purple |
      | Eagle          | purple |
      | Birdie         | blue   |
      | Par            | green  |
      | Bogey          | yellow |
      | Double Bogey   | orange |
      | Triple Bogey   | pink   |
      | Other          | red    |

  # --- Hole Data ---

  Scenario: Per-hole statistics displayed for all 9 holes
    Then 9 HoleStatsCell rows are displayed
    And each shows: hole icon, hole number (with ordinal), par, average, score type name, histogram

  Scenario: Hole stats histogram shows score distribution
    Given hole 3 has been played 15 times
    Then the histogram shows bar counts for scores 2 through 8+
    And the par column has a green highlight (0.2 opacity)
    And scores above 8 are grouped as "8+"

  # --- Rounds List ---

  Scenario: All player rounds listed
    Then all completed rounds for this player are listed
    And each is shown as a RoundCellView
    And tapping a round navigates to its Round Detail View

  # --- Edit ---

  Scenario: Edit button opens Player Entry in edit mode
    When the user taps "Edit" in the toolbar
    Then the Player Entry View is presented as a full-screen cover
    And it is pre-filled with the player's current data
```

---

## Feature: Settings View

```gherkin
Feature: Settings View
  As a golfer
  I want to manage app settings, export data, and view app info
  So that I can back up my data and customize my experience

  Background:
    Given the Settings View is presented as a full-screen cover

  Scenario: Done button dismisses settings
    When the user taps "Done" in the toolbar
    Then the Settings View is dismissed

  # --- Export ---

  Scenario: Export button shows format chooser
    When the user taps the Export button
    Then a confirmation dialog appears with options:
      | Option          | Description              |
      | CSV File        | Export rounds as CSV      |
      | Full Database   | Export complete database   |

  Scenario: Export as CSV creates zip file
    Given the export dialog is shown
    When the user selects "CSV File"
    Then ImportExport.zipCSVData() is called
    And a zip file is created containing one CSV per round
    And the share sheet is presented with the zip file

  Scenario: Export as Full Database creates zip file
    Given the export dialog is shown
    When the user selects "Full Database"
    Then ImportExport.zipData() is called
    And a zip file is created containing database files and player photos
    And the share sheet is presented with the zip file

  Scenario: Export error shows alert
    Given an export operation fails
    Then an alert is shown with the error message
    And an "OK" button dismisses the alert

  # --- Import ---

  Scenario: Import button opens file picker
    When the user taps the Import button
    Then a file importer is presented
    And it accepts only .zip files

  Scenario: Successful import shows confirmation
    Given the user selects a valid zip file
    When the import completes successfully
    Then an alert shows "The import was successful."
    And a didImport notification is posted to refresh the Main View

  Scenario: Failed import shows error
    Given the user selects an invalid zip file
    When the import fails
    Then an alert shows the error message

  # --- Local Rules ---

  Scenario: Local Rules button opens rule sheet
    When the user taps the "Local Rules" button
    Then the Rule View is presented as a sheet

  # --- Support ---

  Scenario: Open an issue link opens GitHub
    When the user taps "Open an issue"
    Then the URL https://github.com/tassinari/MaynardGolf/issues opens in Safari

  # --- About ---

  Scenario: About section displays app info
    Then the following information is displayed:
      | Field       | Value                                                              |
      | App Name    | "Maynard Golf" in headline font                                    |
      | Version     | "Version 1.0" in callout gray                                      |
      | Author      | "by Mark Tassinari" in callout gray                                 |
      | Description | "Maynard golf is a free and open source software project..."        |
      | Disclaimer  | "This app is not associated with the Maynard Golf Club in any way." |
      | GitHub      | Link to https://github.com/tassinari/MaynardGolf                   |
```

---

## Feature: Rule View — Local Rules

```gherkin
Feature: Rule View
  As a golfer at Maynard Golf Course
  I want to see the local rules
  So that I know the house rules while playing

  Background:
    Given the Rule View is presented as a sheet

  Scenario: Title displayed
    Then the title "Local Rules" is shown in headline semibold font

  Scenario: Close button dismisses sheet
    When the user taps the close button
    Then the Rule View sheet is dismissed

  Scenario: All 12 rules displayed as bullet points
    Then 12 rules are listed with bullet points (•)
    And the rules are:
      | # | Rule                                                                                                         |
      | 1 | USGA Rules govern play unless amended by local rules.                                                        |
      | 2 | OUT OF BOUNDS: Parking lot, off club property defined by white stakes.                                       |
      | 3 | Ball coming to rest in a bark mulch area may be lifted and dropped one club length, no nearer the hole, with no penalty. |
      | 4 | All service roads, cart paths, fairway drainage ditches, and protective fences, free lift to nearest point of relief, no nearer the hole. |
      | 5 | Ball coming to rest in the confines of a rock or rocks through the green may be moved one club length without penalty. |
      | 6 | Players not holding their places on golf course must allow other groups to play through.                      |
      | 7 | Players on 1st tee must alternate with players coming off 9th green.                                          |
      | 8 | Do not climb face of bunkers. Rake bunkers and return rake to inside the bunker.                              |
      | 9 | Keep all carts off aprons and greens.                                                                         |
      | 10| Repair ball marks on green. Replace divots.                                                                   |
      | 11| Please speed up play.                                                                                         |
      | 12| Maynard Golf Course is a soft spike facility.                                                                 |
```

---

## Feature: Scorecard Views

```gherkin
Feature: Scorecard Views
  As a golfer
  I want to see a traditional golf scorecard layout
  So that I can read scores in a familiar format

  # --- Vertical Card View ---

  Scenario: Vertical card headers
    Given a round with 2 players "John" and "Jane"
    Then the header row shows: "Hole", "Par", "John", "Jane"
    And the header has a blue background with white text

  Scenario: Vertical card data rows for each hole
    Then 9 data rows are displayed (holes 1-9)
    And even-numbered holes have a light blue background
    And odd-numbered holes have a white background

  Scenario: Vertical card footer shows totals
    Then the footer row shows "Out", a blank cell, and each player's total score
    And the footer has a light blue background

  Scenario: Score markers applied to scores
    Given a player scored 3 on a par 4 (birdie)
    Then the score "3" has a single circle outline (birdie marker)

    Given a player scored 2 on a par 4 (eagle)
    Then the score "2" has double concentric circles (eagle marker)

    Given a player scored 5 on a par 4 (bogey)
    Then the score "5" has a single square outline (bogey marker)

    Given a player scored 6 on a par 4 (double bogey)
    Then the score "6" has double concentric squares (double bogey marker)

    Given a player scored 4 on a par 4 (par)
    Then the score "4" has no marker

  Scenario: Close button on vertical card (when enabled)
    Given showExit is true
    Then a close button with blue background is shown
    When the user taps it
    Then the sheet is dismissed

  # --- Horizontal Card View ---

  Scenario: Horizontal card row structure
    Then the card rows are ordered:
      | Row           | Background    |
      | Hole numbers  | systemGray5   |
      | Par           | systemGray5   |
      | Blue yardages | blue          |
      | White yardages| white         |
      | Player scores | white (each)  |
      | Yellow yardages| yellow       |
      | Red yardages  | red           |
      | Handicap      | systemGray5   |

  Scenario: Horizontal card includes "Out" column
    Then the last column in each row shows the total (Out)

  # --- PDF View ---

  Scenario: PDF renders with header and scorecard
    Then the PDF contains:
      | Element | Content                                |
      | Title   | "Maynard Golf Club" in semibold        |
      | Date    | Round date in caption font              |
      | Body    | Horizontal CardView scorecard           |
```

---

## Feature: Score Marking Rules

```gherkin
Feature: Score Marking
  As a golfer viewing a scorecard
  I want scores marked with standard golf notation
  So that I can quickly identify birdies, bogeys, etc.

  Scenario Outline: Score differential determines marker type
    Given a hole with par <par>
    And a player scored <score>
    Then the score is classified as "<type>"
    And the marker is "<marker>"

    Examples:
      | par | score | type           | marker                  |
      | 4   | 1     | Double Eagle   | double concentric circles |
      | 4   | 2     | Eagle          | double concentric circles |
      | 4   | 3     | Birdie         | single circle             |
      | 4   | 4     | Par            | no marker                 |
      | 4   | 5     | Bogey          | single square             |
      | 4   | 6     | Double Bogey   | double concentric squares |
      | 4   | 7     | Triple Bogey   | double concentric squares |
      | 4   | 8     | Other          | double squares (red if >9)|
      | 3   | 1     | Eagle          | double concentric circles |
      | 3   | 2     | Birdie         | single circle             |
      | 3   | 3     | Par            | no marker                 |
      | 5   | 3     | Eagle          | double concentric circles |
      | 5   | 4     | Birdie         | single circle             |
      | 5   | 5     | Par            | no marker                 |
```

---

## Feature: Handicap Calculation

```gherkin
Feature: Handicap Calculation
  As a golfer
  I want my handicap calculated using USGA methodology
  So that I have an accurate measure of my ability

  Scenario: Minimum rounds required
    Given a player has fewer than 8 completed rounds
    Then handicap returns nil
    And handicap is not displayed in the UI

  Scenario: Handicap calculated from best 8 of 20 differentials
    Given a player has 20 completed non-deleted rounds
    Then the 20 most recent rounds are fetched (sorted by date descending)
    And a score differential is calculated for each round
    And the 8 lowest differentials are selected
    And the handicap is the average of those 8

  Scenario: Score differential formula for 9-hole round
    Given a 9-hole round with gross score <gross>
    Then the adjusted score is <gross> × 2 (doubled to 18-hole equivalent)
    And the differential is (113 / 125.0) × (adjusted_score - 69.1)

  Scenario: Course values for Maynard GC
    Then the slope rating is 125.0
    And the course rating is 69.1
    And the PCC adjustment is 0
```

---

## Feature: Player Trend Calculation

```gherkin
Feature: Player Trend
  As a golfer viewing round results
  I want to see if my performance is trending up or down
  So that I know if I'm improving

  Scenario: Improving trend (lower score)
    Given a player's current round score is 38
    And the average of their 5 most recent previous rounds is 42
    Then the trend is .down (improving)
    And a green down-arrow is displayed

  Scenario: Declining trend (higher score)
    Given a player's current round score is 45
    And the average of their 5 most recent previous rounds is 40
    Then the trend is .up (declining)
    And a red up-arrow is displayed

  Scenario: Trend only shown for complete rounds
    Given the round is not marked as complete
    Then no trend is calculated or displayed
```

---

## Feature: Round In-Progress Detection

```gherkin
Feature: Round In-Progress
  As a golfer
  I want the app to detect rounds currently being played
  So that I can easily resume scoring

  Scenario: Round is in progress
    Given a round was created today
    And at least one hole has no score for at least one player
    Then the round's inProgress property is true
    And it appears in the "In Progress" section of the Main View

  Scenario: Round is not in progress — all scored
    Given a round was created today
    And all 9 holes have scores for all players
    Then inProgress is false

  Scenario: Round is not in progress — different day
    Given a round was created yesterday
    And some holes are unscored
    Then inProgress is false
```

---

## Feature: Data Import/Export

```gherkin
Feature: Data Import and Export
  As a golfer
  I want to back up and restore my data
  So that I don't lose my scoring history

  # --- Full Database Export ---

  Scenario: Full database export creates zip with all data
    When the user exports the full database
    Then a zip file is created in the temp directory
    And it contains the SQLite database files (db, wal, shm)
    And it contains all player avatar photos from pics/
    And the filename is "maynard_golf_archive_YYYY-MM-DD_HH-mm-ss.zip"

  # --- CSV Export ---

  Scenario: CSV export creates per-round files
    When the user exports as CSV
    Then a zip file is created containing one CSV file per round
    And each CSV has columns: Date, Course, Temp, Weather, Tee, Name, 1-9, out
    And the filename is "maynard_golf_archive_csv_YYYY-MM-DD_HH-mm-ss.zip"

  # --- Import ---

  Scenario: Importing a valid zip replaces the database
    Given the user selects a valid database zip file
    When the import is executed
    Then the existing database is backed up to a temp folder
    And the new database files replace the current ones
    And a didImport notification is posted
    And the app refreshes with the imported data

  Scenario: Import failure restores original data
    Given the user selects a zip file
    And the import process encounters an error
    Then the original database is restored from the backup
    And an error message is displayed

  Scenario: Only zip files accepted for import
    When the file importer is presented
    Then it filters to accept only .zip file types
```

---

## Feature: Weather Integration

```gherkin
Feature: Weather Integration
  As a golfer
  I want weather conditions recorded with my round
  So that I can correlate performance with weather

  Scenario: Weather fetched on round creation
    When a new round is created
    Then the app fetches current weather via WeatherKit
    And the location is hardcoded to Maynard GC (42.44241, -71.45150)
    And the temperature and weather icon are stored on the round

  Scenario: Weather displayed on round cell
    Given a round has weather data
    Then the weather icon is displayed on the right side of the RoundCellView

  Scenario: Weather displayed on round detail header
    Given a round has weather data
    Then the weather icon and temperature are shown in the header section

  Scenario: Missing weather data handled gracefully
    Given a round has no weather data (nil)
    Then no weather elements are displayed
```

---

## Feature: Player Image Management

```gherkin
Feature: Player Image Management
  As a golfer
  I want player avatars displayed consistently
  So that players are visually identifiable

  Scenario: Player with photo shows circular avatar
    Given a player has a saved photo
    Then the photo is displayed in a circle with the player's color border (4pt stroke)
    And the photo is scaled and offset per the crop settings

  Scenario: Player without photo shows initials
    Given a player has no saved photo
    Then a gray circle is displayed
    And the player's initials (first letter of first and last name) are shown

  Scenario: Image caching
    Given a player photo is loaded
    Then it is cached in the ImageCache singleton (in-memory)
    And subsequent displays use the cached version
    And the cache is keyed by player UUID

  Scenario: Cache cleared on photo update
    Given a player's photo is updated in edit mode
    Then the ImageCache entry for that player is cleared
    And the new photo is loaded on next display

  Scenario: Photos stored in documents directory
    When a player photo is saved
    Then it is written as PNG to Documents/pics/
    And the player's photoPath stores the relative file path
```

---

## Feature: Stats Window

```gherkin
Feature: Statistics Window
  As a golfer
  I want stats calculated from my last 20 rounds
  So that my statistics reflect recent performance

  Scenario: Stats use last 20 rounds
    Given a player has 30 completed non-deleted rounds
    Then all statistics (handicap, score distribution, min/max/avg, per-hole, graph) use only the 20 most recent

  Scenario: Rounds are filtered for stats
    Then only rounds that are:
      | complete | true  |
      | deleted  | false |
      | contains player | true |
    are included in statistics calculations

  Scenario: Score distribution aggregates by type
    Given a player's last 20 rounds contain scores
    Then the distribution counts each ScoreName type across all holes
    And the result is a dictionary of [ScoreName: Int]

  Scenario: Per-hole average uses fractional scoring ranges
    Given a par 4 hole with average score 3.7
    Then the score type is "Birdie" (range 2.5-3.4 → actually 3.5-4.4 = Par)

  Scenario: Score graph shows chronological data
    Then scores are plotted in date order (ascending)
    And the Y-axis range is (min - 3) to (max + 3) for padding
```

---

## Feature: Navigation System

```gherkin
Feature: Navigation
  As a user
  I want consistent navigation throughout the app
  So that I can easily move between screens

  Scenario: NavigationStack manages main flow
    Then the Main View uses a NavigationStack with path binding
    And NavDestinations enum provides type-safe navigation targets

  Scenario Outline: Navigation destinations resolve correctly
    When navigating to <destination>
    Then <view> is displayed

    Examples:
      | destination             | view              |
      | .roundView(round)       | RoundDetailView   |
      | .playerView(player)     | PlayerDetailView  |
      | .allPlayers             | PlayersView       |
      | .allRounds              | RoundsView        |
      | .deletedRounds          | DeleteRoundView   |

  Scenario: Full-screen covers used for modal flows
    Then SettingsView is presented as fullScreenCover
    And HoleViewContainer is presented as fullScreenCover
    And PlayerEntryView is presented as fullScreenCover

  Scenario: Sheets used for contextual overlays
    Then TeeSelectorView is presented as sheet (medium detent)
    And RuleView is presented as sheet
    And EntryView is presented as sheet (medium detent)
    And YardageFinderContainerView is presented as sheet (medium detent)
    And RoundCompleteView is presented as sheet (medium detent)
    And VerticalCardView is presented as sheet (medium detent)
```
