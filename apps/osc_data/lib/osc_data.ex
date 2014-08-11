defmodule OSC.Data do
  defprotocol Encoding do
    @doc "Encodes OSC messages and their arguments."
    def encode(data)
  end

  defmodule Message do
    defstruct address: "", type_tags: ",", args: []
  end

  defmodule Bundle do
    defstruct time_tag: 0.0, elements: []
  end

  defmodule Blob do
    defstruct data: ""
  end

  defimpl Encoding, for: Message do
    def encode(%Message{address: ""}) do
      {:error, "Address is missing."}
    end
    def encode(%Message{address: addr, type_tags: tt, args: args}) do
      {tags, body} = Enum.reduce args, {tt, ""}, (
        fn (arg, {acc_tags, acc_data}) ->
          {tag, data} = encode arg
          {acc_tags <> tag, acc_data <> data}
        end
        )
      (encode addr) <> (encode tags) <> body
    end
  end

  #defimpl Encoding, for: Bundle do
    #end

  defimpl Encoding, for: Integer do
    def encode(n) when n > 2147483647 or n < -2147483648 do
      {:error, "Number out of range."}
    end
    def encode(n) do
      {"i", <<n :: 32>>}
    end
  end

  defimpl Encoding, for: Float do
    defp pos_exp(n, ex) do
      cond do
        n == 2 -> ex + 1
        n < 2 -> ex
        true -> pos_exp(n/2, ex+1)
      end
    end
    defp pos_exp(n) do
      pos_exp n, 0
    end
    defp neg_exp(n, ex) do
      if n >= 1 do
        ex
      else
        neg_exp(n*2, ex-1)
      end
    end
    defp neg_exp(n) do
      neg_exp n, 0
    end

    # Not completely sure about these limits. This is based on 
    # 2 * :math.pow(2, 127), but with the last digit of the significand
    # reduced by 1, because the significand of an IEEE 754 float must be
    # *less than* 2.
    def encode(n) when n > 3.402823669209384e38 or n < 5.877471754111437e-39 do
      {:error, "Number out of range."}
    end
    def encode(n) when n == 0 do
      {"f", <<0 :: 32>>}
    end
    def encode(n) do
      sign_bit = if n < 0, do: 1, else: 0
      raw_number = abs n
      raw_exponent = cond do
        raw_number == 1 -> 0
        raw_number > 1 -> pos_exp(raw_number)
        true-> neg_exp(raw_number)
      end
      exponent = raw_exponent + 128
      raw_significand = (raw_number / (:math.pow(2, raw_exponent)) - 1) * 10000000
      significand = round (
        if raw_significand > 8388607 do
          raw_significand / 10
        else
          raw_significand
        end )
        {"f", <<sign_bit :: 1, exponent :: 8, significand :: 23>>}
    end
  end

  defimpl Encoding, for: BitString do
    def encode(s) do
      len = byte_size(s)
      data= case rem len, 4 do
        0 -> s <> <<0, 0, 0, 0>>
        1 -> s <> <<0, 0, 0>>
        2 -> s <> <<0, 0>>
        3 -> s <> <<0>>
      end
      {"s", data}
    end
  end

  defimpl Encoding, for: Blob do
    def encode(%Blob{data: d}) do
      raw_len = byte_size d
      padding = case rem raw_len, 4 do
        0 -> <<>>
        1 -> <<0, 0, 0>>
        2 -> <<0, 0>>
        3 -> <<0>>
      end
      data = d <> padding
      len = encode(byte_size data)
      {"b", len <> data
    end
  end

  def encode(x) do
    Encoding.encode x
  end

  def decode(binary) do
    :not_implemented
  end
end
