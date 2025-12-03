# PowerShell script to connect to dev environment and view logs
# 连接到 dev 服务器，切换目录并查看日志文件

# SSH目标服务器配置（包含SSH目标和对应的远程路径前缀）
$SshTargets = @{
    "dev" = "/home/deployer/retail"
    "test" = "/home/deployer/retail"
    "staging" = "/home/deployer/retail"
}

function Show-ToolMenu {
    param(
        [string]$SshTarget,
        [string]$ServerName,
        [string]$LogPath
    )
    
    # 定义工具选项
    $toolOptions = @("vim", "tail -f -n 100")
    $selected = 0
    
    # 菜单循环
    while ($true) {
        Clear-Host
        Write-Host "SSH目标: $SshTarget" -ForegroundColor Yellow
        Write-Host "已选择服务器: $ServerName" -ForegroundColor Green
        Write-Host "请选择查看日志的工具:" -ForegroundColor Green
        Write-Host "↑↓ 选择选项，回车确认" -ForegroundColor Gray
        Write-Host ""
        
        # 显示所有选项
        for ($i = 0; $i -lt $toolOptions.Count; $i++) {
            if ($i -eq $selected) {
                Write-Host "> $($toolOptions[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "  $($toolOptions[$i])" -ForegroundColor White
            }
        }
        
        # 读取按键输入
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # 处理按键
        switch ($key.VirtualKeyCode) {
            38 { # 上箭头
                $selected--
                if ($selected -lt 0) { $selected = $toolOptions.Count - 1 }
            }
            40 { # 下箭头
                $selected++
                if ($selected -ge $toolOptions.Count) { $selected = 0 }
            }
            13 { # 回车键
                # 处理选择
                switch ($selected) {
                    0 { # vim
                        Write-Host "正在连接到 $ServerName 服务器..." -ForegroundColor Green
                        Write-Host "导航到日志目录并使用vim打开spring.log..." -ForegroundColor Green
                        ssh -t $SshTarget "cd $LogPath && vim spring.log"
                        return # 正常退出
                    }
                    1 { # tail -f -n 100
                        Write-Host "正在连接到 $ServerName 服务器..." -ForegroundColor Green
                        Write-Host "使用 tail -f -n 100 查看日志（按 Ctrl+C 退出）..." -ForegroundColor Green
                        ssh -t $SshTarget "cd $LogPath && tail -f -n 100 spring.log"
                        return # 正常退出
                    }
                    default {
                        return
                    }
                }
            }
        }
    }
}

function Show-InteractiveMenu {
    param(
        [string]$SshTarget,
        [string]$RemoteBasePath
    )
    
    # 定义选项
    $options = @("疯摩云 - ACCOUNT", "疯摩云 - SERVICE", "疯摩云 - BINLOG", "OPENAPI")
    $selected = 0

    # 菜单循环
    while ($true) {
        Clear-Host
        Write-Host "SSH目标: $SshTarget" -ForegroundColor Yellow
        Write-Host "请选择要连接的服务器:" -ForegroundColor Green
        Write-Host "↑↓ 选择选项，回车确认" -ForegroundColor Gray
        Write-Host ""

        # 显示所有选项
        for ($i = 0; $i -lt $options.Count; $i++) {
            if ($i -eq $selected) {
                Write-Host "> $($options[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "  $($options[$i])" -ForegroundColor White
            }
        }

        # 读取按键输入
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        # 处理按键
        switch ($key.VirtualKeyCode) {
            38 { # 上箭头
                $selected--
                if ($selected -lt 0) { $selected = $options.Count - 1 }
            }
            40 { # 下箭头
                $selected++
                if ($selected -ge $options.Count) { $selected = 0 }
            }
            13 { # 回车键
                # 处理选择
                switch ($selected) {
                    0 { # 疯摩云 - ACCOUNT
                        Show-ToolMenu -SshTarget $SshTarget -ServerName "疯摩云 - ACCOUNT" -LogPath "$RemoteBasePath/account/logs"
                        return # 正常退出
                    }
                    1 { # 疯摩云 - SERVICE
                        Show-ToolMenu -SshTarget $SshTarget -ServerName "疯摩云 - SERVICE" -LogPath "$RemoteBasePath/service/logs"
                        return # 正常退出
                    }
                    2 { # 疯摩云 - BINLOG
                        Show-ToolMenu -SshTarget $SshTarget -ServerName "疯摩云 - BINLOG" -LogPath "$RemoteBasePath/binlog/logs"
                        return # 正常退出
                    }
                    3 { # OPENAPI
                        Show-ToolMenu -SshTarget $SshTarget -ServerName "OPENAPI" -LogPath "$RemoteBasePath/openapi/logs"
                        return # 正常退出
                    }
                    default {
                        # 处理无效选项
                        Write-Host ""
                        Write-Host "无效选项，请重新运行脚本并选择有效选项。" -ForegroundColor Red
                        Write-Host "按回车键退出..." -ForegroundColor Gray
                        Read-Host
                        return
                    }
                }
            }
        }
    }
}

function Show-SshTargetMenu {
    # 获取SSH目标列表
    $sshTargetList = $SshTargets.Keys | Sort-Object
    $selected = 0
    
    # 菜单循环
    while ($true) {
        Clear-Host
        Write-Host "请选择SSH目标服务器:" -ForegroundColor Green
        Write-Host "↑↓ 选择选项，回车确认" -ForegroundColor Gray
        Write-Host ""
        
        # 显示所有选项
        for ($i = 0; $i -lt $sshTargetList.Count; $i++) {
            $target = $sshTargetList[$i]
            $path = $SshTargets[$target]
            if ($i -eq $selected) {
                Write-Host "> $target ($path)" -ForegroundColor Cyan
            } else {
                Write-Host "  $target ($path)" -ForegroundColor White
            }
        }
        
        # 读取按键输入
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # 处理按键
        switch ($key.VirtualKeyCode) {
            38 { # 上箭头
                $selected--
                if ($selected -lt 0) { $selected = $sshTargetList.Count - 1 }
            }
            40 { # 下箭头
                $selected++
                if ($selected -ge $sshTargetList.Count) { $selected = 0 }
            }
            13 { # 回车键
                # 处理选择
                $selectedTarget = $sshTargetList[$selected]
                $selectedPath = $SshTargets[$selectedTarget]
                Show-InteractiveMenu -SshTarget $selectedTarget -RemoteBasePath $selectedPath
                return # 正常退出
            }
        }
    }
}

# 调用SSH目标选择菜单
Show-SshTargetMenu
