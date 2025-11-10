module WritingYourOwnBeam.Demo6 exposing (main)

import Browser
import Html exposing (Html)
import List.NonEmpty.Zipper as Zipper exposing (Zipper)
import WritingYourOwnBeam.Scheduler as Scheduler exposing (Scheduler)
import WritingYourOwnBeam.Shared as Shared


type alias Model =
    { history : Zipper Scheduler
    , budget : String
    }


type Msg
    = StepForward
    | StepBackward
    | Reset
    | UpdateBudget String
    | ResetWithBudget Int


init : () -> ( Model, Cmd Msg )
init () =
    initWithBudget 1


initWithBudget : Int -> ( Model, Cmd Msg )
initWithBudget budget =
    let
        initialScheduler : Scheduler
        initialScheduler =
            Scheduler.init
                { workType = Scheduler.ReductionsBudget budget
                , program = Scheduler.ex6
                }
    in
    ( { history = Zipper.singleton initialScheduler
      , budget = String.fromInt budget
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StepForward ->
            ( Shared.handleStepForward model
            , Shared.jumpToBottomOfTraces "trace6"
            )

        StepBackward ->
            ( Shared.handleStepBackward model
            , Shared.jumpToBottomOfTraces "trace6"
            )

        Reset ->
            model.budget
                |> String.toInt
                |> Maybe.withDefault 1
                |> initWithBudget

        UpdateBudget budgetStr ->
            ( { model | budget = budgetStr }, Cmd.none )

        ResetWithBudget budgetInt ->
            initWithBudget budgetInt



view : Model -> Html Msg
view model =
    Shared.viewDemoLayout
        { title = "Demo 6: Receiving messages"
        , stepForward = StepForward
        , stepBackward = StepBackward
        , reset = Reset
        , history = model.history
        , schedulerMode = Shared.ProcessTableWithMailbox
        , codeExample = Scheduler.code6
        , traceId = "trace6"
        , additionalControls = []
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
