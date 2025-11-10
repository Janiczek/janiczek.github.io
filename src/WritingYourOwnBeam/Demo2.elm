module WritingYourOwnBeam.Demo2 exposing (main)

import Browser
import Html exposing (Html)
import List.NonEmpty.Zipper as Zipper exposing (Zipper)
import WritingYourOwnBeam.Scheduler as Scheduler exposing (Scheduler)
import WritingYourOwnBeam.Shared as Shared


type alias Model =
    { history : Zipper Scheduler
    }


type Msg
    = StepForward
    | StepBackward
    | Reset


init : () -> ( Model, Cmd Msg )
init () =
    ( { history =
            Scheduler.init
                { program = Scheduler.ex2
                , workType = Scheduler.AllAtOnce
                }
                |> Zipper.singleton
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StepForward ->
            ( Shared.handleStepForward model
            , Shared.jumpToBottomOfTraces "trace2"
            )

        StepBackward ->
            ( Shared.handleStepBackward model
            , Shared.jumpToBottomOfTraces "trace2"
            )

        Reset ->
            init ()



view : Model -> Html Msg
view model =
    Shared.viewDemoLayout
        { title = "Demo 2: Work"
        , stepForward = StepForward
        , stepBackward = StepBackward
        , reset = Reset
        , history = model.history
        , schedulerMode = Shared.SimpleProgram
        , codeExample = Scheduler.code2
        , traceId = "trace2"
        , additionalControls = []
        , budgetControls = Nothing
        }


main : Platform.Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
