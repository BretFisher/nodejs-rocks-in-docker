# DockerCon 2022 Talk: Node.js Rocks in Docker

Want more? [Get my Docker Mastery for Node.js course with a coupon](https://www.bretfisher.com/docker-mastery-for-nodejs/): 9 hours of video to help a Node.js developer use all the best Docker features.

[My other example repositories](https://github.com/bretfisher/bretfisher) including DevOps automation, Docker, and Kubernetes stuff.

## Table of Contents

## Who is this for?

- You know some Node.js
- You know some Docker
- You want more Node+Docker awesomesauce

## Searching for the best Node.js base image

Honestly, this is one of the hardest choices you'll make at first. After supporting Node.js on VMs (and now images) for over a decade, I can say there is no perfect solution. Everything is a compromise. Often you'll be trading simplicy for increased flexibility, security, or smaller images. The farther down the rabit hole I go of "the smallest, most secure, most reliable Node.js image", the stranger the setup seems to get. I do have a recommended setup though, but to convince you, I need to explain how we get there.

### General goals of a base Node.js image

In order of priority, for the final production stage image:

- Tier 1 support by the Node.js team.
- Minimal CVEs. No HIGH or CRITICAL vulnerabilities.
- Version (even to patch level) is controlled, to ensure reproducable builds/tests.
- Doesn't container unneeded packages, like Python or build tools.
- Under 200MB image size.

### Compairing options against our goals

Here's a compairison of the resonable options I've come up with. Most I've tried in real workloads at some point. Some are shown as base images without Node.js just so you can see their CVE count (as of April 2022) and realize their a non-starter. Others are a combo of a base image with Node.js installed (in various ways). Lastly, remember that in multi-stage setups, we can always have one base for dev/build environments and another for test/production.

Important values that distinguish one image from others are bolded.

Highlights of note:

- While Alpine isn't showing CVEs, it's not the smallest image, nor is it a supported [Tier 1](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list) build by the Node.js team. **It's one of the reasons I don't recommend Alpine-based Node.js images**.
- Note my use of `node:16-bullseye-slim`. Then notice the better CVE count of it vs. `node:16-slim`. **Node.js Debian images don't change the Debian version after a major Node version is released.** If you want to combine the latest Node.js LTS with the current Debian stable, you'll need to use a different tag. In this example, Debian 11 (bullseye) is newer than the default `node:16` Debian 10 (buster) release. Why isn't Debian updated? For stability of that Node.js major version. Once you start using a specific Node.js major release (say 16.x), you can expect the underlying Debian major version to not change for any future Node.js 16.x release of official images. Once Debian 11 (bullseye) came out, you would have to change your image tag to specify that Debian version if you wanted to change the Debian base during a Node.js major release cycle. If you don't pin all apt packages, then changing the underlying Debian version to a new major release may cause major package updates that would break your app.
- `debian:11-slim` saves 44MB and 2k files, but **Debian slim has the same CVE count as the default `debian:latest` image**. Too bad.
- **Ubuntu is historially faster to fix CVEs in its LTS than Debian.** You'll notice much lower CVE counts in Ubuntu-based images. It's my go to default base for [JIT-based](https://en.wikipedia.org/wiki/Just-in-time_compilation) programming languages (Node.js, Python, Ruby, etc.)
- Google's [Distroless image](https://github.com/GoogleContainerTools/distroless) only has 1% of the file count compared to the others, yet it still similar CVE numbers to Ubuntu, and only saves 60MB in size. **Is distroless really worth the added complexity?**

| Image | Tier 1 Support | Minimal CVEs (HIGH+CRITICAL)/TOTAL | Version Controlled | Image Size (Files) | Minimal Packages |
| --- | --- | --- | --- | --- | --- |
| node:latest | Yes | 332/853 | **No** | 991MB (203,325) | No |
| node:16 | Yes | 259/1954 | Yes | 906MB (202,898) | No |
| node:16-alpine | **No** | 0/0 | Yes[^1] | 111MB (179,510) | Yes |
| node:16-slim | Yes | 36/131 | Yes | 175MB (182,843) | Yes |
| node:16-bullseye | Yes | 130/947 | Yes | 936MB (201,425) | No |
| node:16-bullseye-slim | Yes | 12/74 | Yes | 186MB (183,416) | Yes |
| debian:latest (no node) | Yes | 12/74 |  | 124MB (182,965) | No |
| debian:11-slim (no node) | Yes | 12/74 |  | 80MB (181,046) | Yes |
| ubuntu:20.04 (no node) | Yes | **0/15** |  | 73MB (179,854) | Yes |
| ubuntu:20.04+nodesource package | Yes | 2/18 | Yes | 188MB (182,609) | No |
| **ubuntu:20.04+node:16-bullseye-slim** | Yes | **0/15** | Yes | 168MB (183,094) | **Yes** |
| **gcr.io/distroless/nodejs:16** | Yes | **1/12** | **No** | **108MB (2,120)** | **Yes** |

[^1]: While Alpine-based images can be version themselves, apk packages you need inside them can't be relelablly versioned over time (eventually packages are pulled from apk and builds will fail.)

### Rulling out Alpine

I'm a fan of the *idea* of Alpine images, but for Node.js, they have several fatal flaws. Alpine image variants are based on [busybox](https://hub.docker.com/_/busybox) and [musl libc](https://musl.libc.org/), which are security focused, but have side affects. The official Alpine-based Node.js image `node:alpine` has multiple non-starters for me:

- Musl libc is only considered [Expiremental by Node.js](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list).
- Alpine package versions can't be **relilablity** pinned at the minor or patch level. You can pin the image tag, but if you pin apk packages inside it, eventually it'll fail to build once the apk system updates the package version.
- Untill recently, many CVE scanners didn't work with Alpine-based images, or worse, would give you false nagatives. Luckily, Trivy and Snyk (the only two I've tested) work properly with apk dependencies now.
- The justification of using Alpine for the sake of image size is over-hyped, and app dependencies are usually far bigger then the base image size itself. I often see Node.js images with 500-800MB of `node_modules` and rendered frontend content. Many other base image options (`node:slim`, `ubuntu`, and distroless) have nearly the same size as Alpine without any of the potental negatives.
- I've personally had multiple prod issues with Alpine that didn't exist in debian-based containers, including file I/O and performance issues. Many others have told me the same over the years and for Node.js (and Python) apps. Prod teams get burned too many times to consider Alpine a safe alternative.

Sorry Alpine fans. It's still a great OS and I still use the `alpine` official image regurarly for utilites and troubleshooting.

### Rulling out `node:latest` or `node:lts`

It's convient to use the standard official images. I prefer the lts options (20.04,22.04) over the latest variants (21.10). However, these non-slim variants were foused on ease of use for new Docker users, and are not as good for production. They include a ton of packages that you'll likely never need in production, like imagemagick, compilers, mysql client, even svn/mercurial. That's why they have hundreds of high and critical CVE's. That's a non-starter for production.

Here's another argument against them that I see with existing (brownfield) apps that are convered to Docker builds. If you start on these non-slim official node images, you may not realize the *true* dependencies of your app, because it turns out you needed more then just the nodejs package, and if you ever switch to a different base image or package manager, you'll find that your app doesn't work, because it needed some apt/yum/apk pacakge that was in the bloated default base images, but aren't included in in slime/alpine/distroless images.

You might think "who doesn't know their exact system depdenencies?". With 10-year old apps, I see it often that teams don't have a true list of everything they need. They might know that on CentOS 7.3 they need x/y/z, but if they swap to a different base, it turns out there was a library included in CentOS for convicene that isn't in that new base.

Docker slim images really help ensure you have an accurate list of apt/yum/apk dependencies.

### Rulling out `node:*-slim`


### Building a custom Node.js image based on ubuntu

OK

One negative here. Most CVE scanners use package lists to determine if a image or system is vunerable. When we COPY in binaries and libraries, those aren't tracked by package systems, so they won't show up on CVE scans. The workaround is to also scan the FROM image that you COPY Node.js from.

### Using distroless

I consider this a more advanced solution, because it doesn't include a shell or any utilities like package managers. A distroless image is something you COPY your app directory tree into as the last Dockerfile stage. It's meant to keep the image at an absolute minimum, and has the low CVE count to match.

One negactive