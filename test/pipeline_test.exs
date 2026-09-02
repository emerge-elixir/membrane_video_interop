defmodule Membrane.VideoInterop.PipelineTest do
  use ExUnit.Case, async: false

  defmodule Pipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(_ctx, owner) do
      spec =
        child(:source, %Membrane.VideoInterop.Source{notify: self(), message_tag: :frame})
        |> child(:sink, %Membrane.VideoInterop.Sink{
          submit: {Membrane.VideoInterop.PipelineTest, :submit, [owner]},
          target: :preview
        })

      {[spec: spec], %{owner: owner}}
    end

    @impl true
    def handle_info({:video_interop_source_ready, source}, _ctx, state) do
      send(state.owner, {:source_ready, self(), source})
      {[], state}
    end

    def handle_info(_message, _ctx, state), do: {[], state}
  end

  test "transports frames through demand and restarts cleanly" do
    for generation <- 1..2 do
      assert {:ok, _supervisor, pipeline} = Membrane.Pipeline.start_link(Pipeline, self())
      assert_receive {:source_ready, ^pipeline, source}, 1_000

      frame =
        VideoInterop.Frame.binary(<<generation, 0, 0, 255>>,
          width: 1,
          height: 1,
          pixel_format: :rgba8888
        )

      send(source, {:frame, frame})
      assert_receive {:submitted, ^frame, :preview}, 1_000
      assert :ok = Membrane.Pipeline.terminate(pipeline)
    end
  end

  def submit(frame, target, owner) do
    send(owner, {:submitted, frame, target})
    VideoInterop.release(frame)
  end
end
