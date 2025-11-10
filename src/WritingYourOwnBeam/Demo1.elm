module WritingYourOwnBeam.Demo1 exposing (main)

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
                { workType = Scheduler.AllAtOnce
                , program = Scheduler.ex1
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
            , Shared.jumpToBottomOfTraces "trace1"
            )

        StepBackward ->
            ( Shared.handleStepBackward model
            , Shared.jumpToBottomOfTraces "trace1"
            )

        Reset ->
            ( { model
                | history =
                    Zipper.singleton
                        (Scheduler.init
                            { workType = Scheduler.AllAtOnce
                            , program = Scheduler.ex1
                            }
                        )
              }
            , Cmd.none
            )



view : Model -> Html Msg
view model =
    Shared.viewDemoLayout
        { title = "Demo 1: End"
        , stepForward = StepForward
        , stepBackward = StepBackward
        , reset = Reset
        , history = model.history
        , schedulerMode = Shared.SimpleProgram
        , codeExample = Scheduler.code1
        , traceId = "trace1"
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
