# JOBS!
cls
$jobs = 1..2 | Start-Job -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}

$jobs | receive-job -wait




# Works as expected, except the terminating error cancelled receiving the 2nd job :(
# Lets try with no exception:
$jobs = 1..2 | Start-Job -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
}
$jobs | receive-job -wait




# Wait, what? You can't pipe to start job, but we only found that out after the 'throw' was removed. Lets try that again:
$jobs = foreach ($i in 1..2) { Start-Job -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
} }
$jobs | receive-job -wait



# Awesome! But wait, was that why we only got a single set of output on the first run? Lets try with the exception again, without piping:
$jobs = foreach ($i in 1..2) { Start-Job -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
} }
$jobs | Receive-Job -wait





# Ahhhhh, so Start-Job | Receive-Job -Wait is consistent even for exceptions, it just behaves weirdly when you pipe to it but have a scriptblock that throws.


# RSJOBS!
cls
$rsJobs = 1..2 | Start-RSJob -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}
$rsJobs | Wait-RSJob | Receive-RSJob




# Verbose then warning then error? Our host and our output streams got eaten. Lets try that without the exception...

$rsJobs = 1..2 | Start-RSJob -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
}
$rsJobs | Wait-RSJob | Receive-RSJob





# Ah, now we get our output. Still no host (but who really cares, write-host is generally accepted to be bad...)
# But it certainly doesn't show up in the order it was output, making for difficult debugging.



# THREADJOBS!
cls
$jobs = 1..2 | Start-ThreadJob -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}
$jobs | % { $_ | receive-job -wait }





# Hmm, the non-terminating error output the whole scriptblock as context. 
# I almost like that, except that it didn't behave like that for the exception
# Verbose is straight up gone. Maybe we'll try with no errors?

$jobs = 1..2 | Start-ThreadJob -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
}
$jobs | receive-job -wait





# Nope, verbose is still gone. How about with -Verbose on the receive?
$jobs = 1..2 | Start-ThreadJob -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}
$jobs | receive-job -wait -Verbose






# Ah, there it is. I would expect the Write-Verbose -Verbose to force verbose output as it does everywhere else. 
# Instead the Verbose stream gets eaten unless you receive the job with -verbose.
# Order of output IS preserved however.


# INVOKE-PARALLEL
cls
1..2 | Invoke-Parallel -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}



# Output gets eaten :( Lets try again with no exception?

1..2 | Invoke-Parallel -ScriptBlock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
}



# Ah, there we go. Output last. Note that the non-output-non-error streams from ALL jobs are output first before the errors and output are. Frustrating to debug if you were actually trying to understand what was happening here.


# START-PARALLEL
cls
1..2 | Start-Parallel -Scriptblock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
}



# Oooooohhhhhhhhhhhhhh, if you get an error with this one it just eats all of your output. Ouch. What about with no exception?
1..2 | Start-Parallel -Scriptblock {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
}




# Hmm. Gonna have to pass on this one. No combination of stuff in here got me anything other than exception OR output stream.


# SPLIT-PIPELINE
cls
1..2 | Split-Pipeline -Script { process {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
    throw "Finally, lets cap things off with a nice exception."
} }




# Hmm, the streams are a little muddy here. We get the first and second threads host output, we miss the write-output, and miss the 2nd ones verbose and warning output. What about if we get rid of the exception?

1..2 | Split-Pipeline -Script { process {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
} }


# Alright, that resolved our missing output issue. So important that you catch terminating errors in split pipeline (or don't have them), if you want clear debugging output.
# Output is out of order with the other streams :(
# The errors don't come in order with the item that they were processing either.

1..2 | Split-Pipeline -Script { process {
    Write-Host "First, host"
    Write-Verbose -Verbose "Second, verbose!"
    Write-Output "Third how about output!"
    Write-Warning "Ooh, Fourth lets try a warning."
    Write-Error "how about a non-terminating error?"
} } -Order



# Not even the -Order parameter saves us from this behavior. The -Order parameter enforces that the output from your objects are output in the same order that they went in.
# For example, 
1..100 | Split-Pipeline {process{ Start-Sleep -Seconds 1; $_} }
# Does not guarantee that you get the numbers back out in the same order they went in. The -Order flag will fix that at the expense of live output:
1..100 | Split-Pipeline {process{ Start-Sleep -Seconds 1; $_} } -Order

# For most of the other techniques, output order is not really a priority since you don't think about them in terms of a loop.
# However for split-pipeline, because it looks and feels like a loop, it is much easier to make the mistake of assuming your output will come in the same order that the input went in, so I felt it was important to call out the -Order parameter explicitly on this one.