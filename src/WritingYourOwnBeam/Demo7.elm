module WritingYourOwnBeam.Demo7 exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes
import Html.Events
import List.NonEmpty.Zipper as Zipper exposing (Zipper)
import WritingYourOwnBeam.Scheduler as Scheduler exposing (Scheduler)
import WritingYourOwnBeam.Shared as Shared


type alias Model =
    { history : Zipper Scheduler
    , budget : String
    , isFixedVersion : Bool
    }


type Msg
    = StepForward
    | StepBackward
    | Reset
    | FixBug
    | UpdateBudget String
    | ResetWithBudget Int


init : () -> ( Model, Cmd Msg )
init () =
    initWithBudget 1


initWithBudget : Int -> ( Model, Cmd Msg )
initWithBudget budget =
    initWithBudgetAndProgram budget { fixed = False }


initWithBudgetAndProgram : Int -> { fixed : Bool } -> ( Model, Cmd Msg )
initWithBudgetAndProgram budget { fixed } =
    let
        initialScheduler : Scheduler
        initialScheduler =
            Scheduler.init
                { workType = Scheduler.ReductionsBudget budget
                , program =
                    if fixed then
                        Scheduler.ex7b

                    else
                        Scheduler.ex7
                }
    in
    ( { history = Zipper.singleton initialScheduler
      , budget = String.fromInt budget
      , isFixedVersion = fixed
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StepForward ->
            ( Shared.handleStepForward model
            , Shared.jumpToBottomOfTraces "trace7"
            )

        StepBackward ->
            ( Shared.handleStepBackward model
            , Shared.jumpToBottomOfTraces "trace7"
            )

        Reset ->
            model.budget
                |> String.toInt
                |> Maybe.withDefault 1
                |> initWithBudget

        FixBug ->
            let
                budget : Int
                budget =
                    model.budget
                        |> String.toInt
                        |> Maybe.withDefault 1
            in
            initWithBudgetAndProgram budget { fixed = True }

        UpdateBudget budgetStr ->
            ( { model | budget = budgetStr }, Cmd.none )

        ResetWithBudget budgetInt ->
            initWithBudget budgetInt



view : Model -> Html Msg
view model =
    let
        additionalControls : List (Html Msg)
        additionalControls =
            [ Html.button
                [ Html.Attributes.class "demo-button"
                , Html.Events.onClick FixBug
                , Html.Attributes.style "padding" "8px 16px"
                , Html.Attributes.style "font-family" "'JetBrains Mono', monospace"
                ]
                [ Html.text "Fix the bug" ]
            ]
    in
    Shared.viewDemoLayout
        { title = "Demo 7: Link, Crash and a surprise"
        , stepForward = StepForward
        , stepBackward = StepBackward
        , reset = Reset
        , history = model.history
        , schedulerMode = Shared.ProcessTableWithMailbox
        , codeExample =
            if model.isFixedVersion then
                Scheduler.code7b

            else
                Scheduler.code7
        , traceId = "trace7"
        , additionalControls = additionalControls
        , budgetControls =
            Just
                { resetWithBudget = ResetWithBudget
                , updateBudget = UpdateBudget
                , budgetField = model.budget
                }
        }


main : Platform.Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
