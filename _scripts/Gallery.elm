module Gallery exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes
import Html.Events
import List.Extra


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Flags =
    { filename : String
    , pattern : String
    , min : Int
    , max : Int
    }


type alias Model =
    { images : List String
    , current : Int
    , hovered : Maybe Int
    }


type Msg
    = GoLeft
    | GoRight
    | GoTo Int
    | Hover Int
    | StopHovering


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { images =
            List.range flags.min flags.max
                |> List.map
                    (\i ->
                        flags.filename
                            |> String.replace flags.pattern (String.fromInt i)
                    )
      , current = 0
      , hovered = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GoLeft ->
            ( { model | current = max 0 (model.current - 1) }
            , Cmd.none
            )

        GoRight ->
            ( { model | current = min (List.length model.images - 1) (model.current + 1) }
            , Cmd.none
            )

        GoTo n ->
            ( { model | current = clamp 0 (List.length model.images - 1) n }
            , Cmd.none
            )

        Hover n ->
            ( { model | hovered = Just n }, Cmd.none )

        StopHovering ->
            ( { model | hovered = Nothing }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        currentImage =
            case List.Extra.getAt (currentIndex model) model.images of
                Nothing ->
                    Html.text "TODO no current image"

                Just image ->
                    Html.img [ Html.Attributes.src image ] []

        prefetchLinks =
            model.images
                |> List.map
                    (\image ->
                        Html.node "link"
                            [ Html.Attributes.rel "prefetch"
                            , Html.Attributes.href image
                            ]
                            []
                    )
    in
    Html.div
        []
        (currentImage
            :: viewControls model
            :: prefetchLinks
        )


currentIndex : Model -> Int
currentIndex model =
    model.hovered
        |> Maybe.withDefault model.current


viewControls : Model -> Html Msg
viewControls model =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "row"
        , Html.Attributes.style "gap" "8px"
        , Html.Attributes.style "user-select" "none"
        ]
        [ Html.node "style" [] [ Html.text """
.gallery-arrow:hover {
    color: #ffa629;
}
""" ]
        , Html.div
            [ Html.Attributes.style "display" "flex"
            , Html.Attributes.style "flex-direction" "row"
            , Html.Attributes.style "flex-wrap" "wrap"
            , Html.Attributes.style "flex" "1"
            , Html.Attributes.style "align-items" "center"
            ]
            (model.images
                |> List.indexedMap
                    (\i _ ->
                        let
                            ( borderColor, bgColor ) =
                                if model.hovered == Just i then
                                    ( "#ffa629", "#ffa629" )

                                else if model.current == i then
                                    ( "#888", "#888" )

                                else
                                    ( "#888", "transparent" )

                            size =
                                "8px"
                        in
                        Html.div
                            [ Html.Events.onClick (GoTo i)
                            , Html.Events.onMouseOver (Hover i)
                            , Html.Events.onMouseOut StopHovering
                            , Html.Attributes.style "width" size
                            , Html.Attributes.style "height" size
                            , Html.Attributes.style "cursor" "pointer"
                            ]
                            [ Html.div
                                [ Html.Attributes.style "border-radius" "50%"
                                , Html.Attributes.style "border-style" "solid"
                                , Html.Attributes.style "border-width" "1px"
                                , Html.Attributes.style "width" size
                                , Html.Attributes.style "height" size
                                , Html.Attributes.style "background-color" bgColor
                                , Html.Attributes.style "border-color" borderColor
                                ]
                                []
                            ]
                    )
            )
        , Html.div
            [ Html.Events.onClick GoLeft
            , Html.Attributes.class "gallery-arrow"
            , Html.Attributes.style "cursor" "pointer"
            ]
            [ Html.text "←" ]
        , Html.div
            [ Html.Events.onClick GoRight
            , Html.Attributes.class "gallery-arrow"
            , Html.Attributes.style "cursor" "pointer"
            ]
            [ Html.text "→" ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
