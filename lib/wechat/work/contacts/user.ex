defmodule WeChat.Work.Contacts.User do
  @moduledoc "通讯录管理-成员管理"

  import Jason.Helpers
  import WeChat.Utils, only: [work_doc_link_prefix: 0]
  alias WeChat.Work
  alias Work.Contacts.{Department, Tag}

  @doc_link "#{work_doc_link_prefix()}/90135"

  @typedoc """
  每个成员都有唯一的 userid -
  [官方文档](#{@doc_link}/90665#userid)

  即所谓“帐号”。在管理后台->“通讯录”->点进某个成员的详情页，可以看到。
  """
  @type userid :: String.t()
  @type userid_list :: [userid]
  @typedoc """
  qrcode尺寸类型

  - 1: 171 x 171
  - 2: 399 x 399
  - 3: 741 x 741
  - 4: 2052 x 2052
  """
  @type size_type :: 1..4

  @doc """
  创建成员 -
  [官方文档](#{@doc_link}/92195){:target="_blank"}
  """
  @spec create(Work.client(), body :: map) :: WeChat.response()
  def create(client, body) do
    client.post("/cgi-bin/user/create", body,
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  读取成员 -
  [官方文档](#{@doc_link}/92196){:target="_blank"}

  在通讯录同步助手中此接口可以读取企业通讯录的所有成员信息，而自建应用可以读取该应用设置的可见范围内的成员信息。
  """
  @spec get(Work.client(), userid) :: WeChat.response()
  def get(client, userid) do
    client.get("/cgi-bin/user/get",
      query: [userid: userid, access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  更新成员 -
  [官方文档](#{@doc_link}/92197){:target="_blank"}
  """
  @spec update(Work.client(), body :: map) :: WeChat.response()
  def update(client, body) do
    client.post("/cgi-bin/user/update", body,
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  删除成员 -
  [官方文档](#{@doc_link}/92198){:target="_blank"}
  """
  @spec delete(Work.client(), userid) :: WeChat.response()
  def delete(client, userid) do
    client.get("/cgi-bin/user/delete",
      query: [userid: userid, access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  批量删除成员 -
  [官方文档](#{@doc_link}/92199){:target="_blank"}

  对应管理端的帐号。最多支持200个。若存在无效UserID，直接返回错误
  """
  @spec batch_delete(Work.client(), userid_list) :: WeChat.response()
  def batch_delete(client, userid_list) do
    client.post("/cgi-bin/user/batchdelete", json_map(useridlist: userid_list),
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  获取部门成员列表(简要) -
  [官方文档](#{@doc_link}/90200){:target="_blank"}

  获取部门成员列表

  `fetch_child` 是否递归获取子部门下面的成员：
  - `1`: 递归获取
  - `0`: 只获取本部门
  """
  @spec list_department_users(Work.client(), Department.party_id()) :: WeChat.response()
  def list_department_users(client, department_id, fetch_child \\ 0) do
    client.get("/cgi-bin/user/simplelist",
      query: [
        department_id: department_id,
        fetch_child: fetch_child,
        access_token: client.get_access_token(:contacts)
      ]
    )
  end

  @doc """
  获取部门成员列表(详情) -
  [官方文档](#{@doc_link}/90201){:target="_blank"}

  获取部门成员列表(详情)

  `fetch_child` 是否递归获取子部门下面的成员：
  - `1`: 递归获取
  - `0`: 只获取本部门
  """
  @spec list_department_users_detail(Work.client(), Department.party_id()) :: WeChat.response()
  def list_department_users_detail(client, department_id, fetch_child \\ 0) do
    client.get("/cgi-bin/user/list",
      query: [
        department_id: department_id,
        fetch_child: fetch_child,
        access_token: client.get_access_token(:contacts)
      ]
    )
  end

  @doc """
  userid转openid -
  [官方文档](#{@doc_link}/90202){:target="_blank"}

  该接口使用场景为企业支付，在使用企业红包和向员工付款时，需要自行将企业微信的 `userid` 转成 `openid`。

  注：需要成员使用微信登录企业微信或者关注微工作台（原企业号）才能转成 `openid`;
  如果是外部联系人，请使用外部联系人 `openid` 转换 `openid`
  """
  @spec userid2openid(Work.client(), userid) :: WeChat.response()
  def userid2openid(client, userid) do
    client.post("/cgi-bin/user/convert_to_openid", json_map(userid: userid),
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  openid转userid -
  [官方文档](#{@doc_link}/90202){:target="_blank"}

  该接口主要应用于使用企业支付之后的结果查询。
  开发者需要知道某个结果事件的 `openid` 对应企业微信内成员的信息时，可以通过调用该接口进行转换查询。
  """
  @spec openid2userid(Work.client(), WeChat.openid()) :: WeChat.response()
  def openid2userid(client, openid) do
    client.post("/cgi-bin/user/convert_to_userid", json_map(openid: openid),
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  二次验证 -
  [官方文档](#{@doc_link}/90203){:target="_blank"}

  此接口可以满足安全性要求高的企业进行成员验证。开启二次验证后，当且仅当成员登录时，需跳转至企业自定义的页面进行验证。验证频率可在设置页面选择。

  企业在开启二次验证时，必须在管理端填写企业二次验证页面的url。

  当成员登录企业微信或关注微工作台（原企业号）进入企业时，会自动跳转到企业的验证页面。在跳转到企业的验证页面时，会带上如下参数：code=CODE。

  企业收到code后，使用 “通讯录同步助手” 调用接口 “[根据code获取成员信息](Work.App.sso_user_info/3)” 获取成员的userid。

  如果成员是首次加入企业，企业获取到userid，并验证了成员信息后，调用如下接口即可让成员成功加入企业。
  """
  @spec join_confirm(Work.client(), userid) :: WeChat.response()
  def join_confirm(client, userid) do
    client.get("/cgi-bin/user/authsucc",
      query: [userid: userid, access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  邀请成员 -
  [官方文档](#{@doc_link}/90975){:target="_blank"}

  企业可通过接口批量邀请成员使用企业微信，邀请后将通过短信或邮件下发通知。
  """
  @spec batch_invite(
          Work.client(),
          nil | userid_list,
          nil | Department.party_id_list(),
          nil | Tag.tag_id_list()
        ) :: WeChat.response()
  def batch_invite(client, userid_list, party_id_list, tag_id_list) do
    body =
      [user: List.wrap(userid_list), party: List.wrap(party_id_list), tag: List.wrap(tag_id_list)]
      |> Enum.reject(&Enum.empty?(elem(&1, 1)))
      |> Map.new()

    client.post("/cgi-bin/batch/invite", body,
      query: [access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  获取加入企业二维码 -
  [官方文档](#{@doc_link}/91714){:target="_blank"}

  支持企业用户获取实时成员加入二维码。
  """
  @spec get_join_qrcode(Work.client(), size_type) :: WeChat.response()
  def get_join_qrcode(client, size_type) do
    client.get("/cgi-bin/corp/get_join_qrcode",
      query: [size_type: size_type, access_token: client.get_access_token(:contacts)]
    )
  end

  @doc """
  获取企业活跃成员数 -
  [官方文档](#{@doc_link}/92714){:target="_blank"}

  支持企业用户获取实时成员加入二维码。
  """
  @spec get_active_stat(Work.client(), date :: String.t() | Date.t()) :: WeChat.response()
  def get_active_stat(client, date) do
    client.post("/cgi-bin/user/get_active_stat", json_map(date: date),
      query: [access_token: client.get_access_token(:contacts)]
    )
  end
end
