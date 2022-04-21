# DockerCon 2022 Talk: Node.js Rocks in Docker

Want more? [Get my Docker Mastery for Node.js course with a coupon](https://www.bretfisher.com/docker-mastery-for-nodejs/): 9 hours of video to help a Node.js developer use all the best Docker features.

Also, [My other example repositories](https://github.com/bretfisher/bretfisher) including DevOps automation, Docker, and Kubernetes stuff.

## Who is this for?<!-- omit in toc -->

**- You know some Node.js**
**- You know some Docker**
**- You want more Node+Docker awesomesauce**
  
## Table of Contents<!-- omit in toc -->

- [Searching for the best Node.js base image](#searching-for-the-best-nodejs-base-image)
  - [TL;DR](#tldr)
  - [General goals of a base Node.js image](#general-goals-of-a-base-nodejs-image)
  - [Compairing options against our goals](#compairing-options-against-our-goals)
  - [Ruling out Alpine](#ruling-out-alpine)
  - [Ruling out `node:latest` or `node:lts`](#ruling-out-nodelatest-or-nodelts)
  - [Ruling out `node:*-slim`](#ruling-out-node-slim)
  - [Building a custom Node.js image based on ubuntu](#building-a-custom-nodejs-image-based-on-ubuntu)
    - [Ruling out NodeSource deb packages](#ruling-out-nodesource-deb-packages)
  - [My favorite custom Node.js base image](#my-favorite-custom-nodejs-base-image)
  - [Using distroless](#using-distroless)
    - [The better distroless setup](#the-better-distroless-setup)
- [Dockerfile best practices for Node.js](#dockerfile-best-practices-for-nodejs)
  - [Add Multi-Stage For a Single Dev-Test-Prod Dockerfile](#add-multi-stage-for-a-single-dev-test-prod-dockerfile)
  - [Use `npm ci --only=production` first, then layer dev/test on top](#use-npm-ci---onlyproduction-first-then-layer-devtest-on-top)
- [Add multi-architecture builds](#add-multi-architecture-builds)
- [Proper Node.js shutdown](#proper-nodejs-shutdown)



## Searching for the best Node.js base image

Honestly, this is one of the hardest choices you'll make at first. After supporting Node.js on VMs (and now images) for over a decade, I can say there is no perfect solution. Everything is a compromise. Often you'll be trading simplicy for increased flexibility, security, or smaller images. The farther down the rabit hole I go of "the smallest, most secure, most reliable Node.js image", the stranger the setup seems to get. I do have a recommended setup though, but to convince you, I need to explain how we get there.

### TL;DR

Below I list all the data and justification for my recommendations, but if you just want the result, then:

- General dev/test/prod image that's easy to use: `node:16-bullseye-slim`
- Better image that has less CVE's, build your own base with `ubuntu:20.04` and Node install (official build, image COPY, or deb package)
- Tiny prod image that's using a supported Node.js build: `gcr.io/distroless/nodejs:16`

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
- CVE counts are a moving target, so I don't make long-term image decisions base on a small CVE count difference (under 10), but we see a trend here. The High+Critical is the most important, and these images options tend to have under twenty, or **hundreds**. You can't reason with hundreds. It's a non-starter. It's very rare that anyone's going to analize that many and determine your true risk. With under twenty, someone can evaluate each for the "true risk" in that use case (e.g. is the vunerable file even executied). Anything that's "zero CVEs" won't always be zero.

| Image Name                             | Tier 1 Support | CVEs (High+Crit)/TOTAL | Node Version Control | Image Size (Files) | Min Pkgs |
| -------------------------------------- | -------------- | ---------------------- | -------------------- | ------------------ | -------- |
| node:latest                            | Yes            | 332/853                | **No**               | 991MB (203,325)    | No       |
| node:16                                | Yes            | 259/1954               | Yes                  | 906MB (202,898)    | No       |
| node:16-alpine                         | **No**         | 0/0                    | Yes[^1]              | 111MB (179,510)    | Yes      |
| node:16-slim                           | Yes            | 36/131                 | Yes                  | 175MB (182,843)    | Yes      |
| node:16-bullseye                       | Yes            | 130/947                | Yes                  | 936MB (201,425)    | No       |
| node:16-bullseye-slim                  | Yes            | 12/74                  | Yes                  | 186MB (183,416)    | Yes      |
| debian:latest (no node)                | Yes            | 12/74                  |                      | 124MB (182,965)    | No       |
| debian:11-slim (no node)               | Yes            | 12/74                  |                      | 80MB (181,046)     | Yes      |
| ubuntu:20.04 (no node)                 | Yes            | **0/15**               |                      | 73MB (179,854)     | Yes      |
| ubuntu:20.04+nodesource package        | Yes            | 2/18                   | Yes                  | 188MB (182,609)    | No       |
| **ubuntu:20.04+node:16-bullseye-slim** | Yes            | **0/15**               | Yes                  | 168MB (183,094)    | **Yes**  |
| **gcr.io/distroless/nodejs:16**        | Yes            | **1/12**               | **No**[^2]           | **108MB (2,120)**  | **Yes**  |

[^1]: While Alpine-based images can be version themselves, apk packages you need inside them can't be relelablly versioned over time (eventually packages are pulled from apk and builds will fail.)
[^2]: Distroless can only be pinned (in image tag) to the major Node.js version. That is disapointing. You can technically use the sha256 hash of any image to pin for determinstic builds, but the process for doing so (and determining what hashes are which verions later) is far from ideal.

### Ruling out Alpine

I'm a fan of the *idea* of Alpine images, but for Node.js, they have several fatal flaws. Alpine image variants are based on [busybox](https://hub.docker.com/_/busybox) and [musl libc](https://musl.libc.org/), which are security focused, but have side affects. The official Alpine-based Node.js image `node:alpine` has multiple non-starters for me:

- Musl libc is only considered [Expiremental by Node.js](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list).
- Alpine package versions can't be **relilablity** pinned at the minor or patch level. You can pin the image tag, but if you pin apk packages inside it, eventually it'll fail to build once the apk system updates the package version.
- Untill recently, many CVE scanners didn't work with Alpine-based images, or worse, would give you false nagatives. Luckily, Trivy and Snyk (the only two I've tested) work properly with apk dependencies now.
- The justification of using Alpine for the sake of image size is over-hyped, and app dependencies are usually far bigger then the base image size itself. I often see Node.js images with 500-800MB of `node_modules` and rendered frontend content. Many other base image options (`node:slim`, `ubuntu`, and distroless) have nearly the same size as Alpine without any of the potental negatives.
- I've personally had multiple prod issues with Alpine that didn't exist in debian-based containers, including file I/O and performance issues. Many others have told me the same over the years and for Node.js (and Python) apps. Prod teams get burned too many times to consider Alpine a safe alternative.

Sorry Alpine fans. It's still a great OS and I still use the `alpine` official image regurarly for utilites and troubleshooting.

### Ruling out `node:latest` or `node:lts`

It's convient to use the standard official images. I prefer the lts options (20.04,22.04) over the latest variants (21.10). However, these non-slim variants were foused on ease of use for new Docker users, and are not as good for production. They include a ton of packages that you'll likely never need in production, like imagemagick, compilers, mysql client, even svn/mercurial. That's why they have hundreds of high and critical CVE's. That's a non-starter for production.

Here's another argument against them that I see with existing (brownfield) apps that are convered to Docker builds. If you start on these non-slim official node images, you may not realize the *true* dependencies of your app, because it turns out you needed more then just the nodejs package, and if you ever switch to a different base image or package manager, you'll find that your app doesn't work, because it needed some apt/yum/apk pacakge that was in the bloated default base images, but aren't included in in slime/alpine/distroless images.

You might think "who doesn't know their exact system depdenencies?". With 10-year old apps, I see it often that teams don't have a true list of everything they need. They might know that on CentOS 7.3 they need x/y/z, but if they swap to a different base, it turns out there was a library included in CentOS for convicene that isn't in that new base.

Docker slim images really help ensure you have an accurate list of apt/yum/apk dependencies.

### Ruling out `node:*-slim`


### Building a custom Node.js image based on ubuntu



One negative here. Most CVE scanners use package lists to determine if a image or system is vunerable. When we COPY in binaries and libraries, those aren't tracked by package systems, so they won't show up on CVE scans. The workaround is to also scan the FROM image that you COPY Node.js from.

#### Ruling out NodeSource deb packages

NodeSource provides the official Debian (apt) packages, but they have issues and limitations, which is ultmiatly why I don't use them often for custom built node base images.

1. The pacakge repositories drop off old versions, so you can't pin a Node.js version. A workaround is to manually download the .deb file and "pin" to its URL. This isn't a big deal, but it is a downside to adoption. People either have to discover this through trial and error, or are already apt-pros.
2. It requires Python3 to isntall Node.js. Um, what?  Yes. Every time you use a NodeSource apt package, you are adding Python 3.x minimal and any potential CVEs that come with them. I've figured out it's 20MB of additional stuff.

### My favorite custom Node.js base image

I didn't want to do this. I prefer easy. I prefer someone *else* maintain my node base image, but here we are. The other options aren't great and given that this has worked so well for me, I'm now recommending and using this with others.  Tell me what you think in this GitHub repositories Discussions tab, on [Twitter](https://twitter.com/bretfisher), or in my [DevOps Discord Server](https://devops.fan).

**The smallest image, with the least CVEs, and a shell + package manager included:**

**Use a stock ubuntu LTS image, and COPY in the Node.js binaries and libraries from the official Node.js slim image.**

It basically looks like this, with a full example in [./dockerfiles/ubuntu-copy.Dockerfile](./dockerfiles/ubuntu-copy.Dockerfile):

```Dockerfile
FROM node:16.14.2-slim as node
FROM ubuntu:focal-20220404 as base
COPY --from=node /usr/local/include/ /usr/local/include/
COPY --from=node /usr/local/lib/ /usr/local/lib/
COPY --from=node /usr/local/bin/ /usr/local/bin/
# this ensures we fix simlinks for npx, Yarn, and PnPm
RUN corepack disable && corepack enable
ENTRYPOINT ["/usr/local/bin/node"]
# rest of your stuff goes here
```

Note, if you don't like this COPY method, and feel it's a bit hacky, you could also just download the Node.js distros from nodejs.org and copy the binaries and libraries into your image. This is what the [official Node.js slim image does](https://github.com/nodejs/docker-node/blob/6e8f32de3f620833e563e9f2b427d50055783801/16/bullseye-slim/Dockerfile), but it's a bit more complex then my example above that just copies from one official image to another.

### Using distroless

I consider this a more advanced solution, because it doesn't include a shell or any utilities like package managers. A distroless image is something you COPY your app directory tree into as the last Dockerfile stage. It's meant to keep the image at an absolute minimum, and has the low CVE count to match.

**It cuts the base image file count to 1% of the others, which is amazing**, but it doesn't lesson the CVEs compared to Ubuntu and only saves us 60MB over ubuntu+node. It also isn't usable in dev or test stages because they often need a shell and pacakge manager.

Also, and I can't believe this is an issue, but the distroless images can't easily be pinned to a specific version. It can only be pinned to the Major version, like `gcr.io/distroless/nodejs:16`. So those of us who want determinatic builds, can't use the version tag. A determinstic build would mean that every component is pinned to the exact version and if we built the image two times, a month apart, that nothing should be different. Now, distroless can be determinastic if you pin the sha256 hash of the image, not the version. But each time they ship a image update, the `16` tag is reused and there's no way to go back and see what hashes match old versions (without your own manual tracking), so this isn't good.

So, while I think the ubuntu+node solution is less secure than distroless in theory, the CVE improvement in distroless just isn't there (today) to justify this extra effort of using it. I could be convinced otherwise though, so here's how I would use it:

#### The better distroless setup

My recommended usage usage is to set `node:*-slim` everywhere execpt the final production stage, where you `COPY --chown=1000:1000 /app` to distroless... AND you also pin to the sha256 hash of your specific distroless image, then I think that's a reasonable solution. If you're tracking both images well, you can be sure that your distroless is using the same base Debian that your official `node:*-slim` image is. That's ideal, then any dev/test OS (apt) libraries will be very close or identical.

Get the full image name:id with the sha256 hash from the registry by downloading the image and inspecting it. You're looking for the `RepoDigests`, or just grep like this:

```shell
docker pull docker gcr.io/distroless/nodejs:16
docker inspect gcr.io/distroless/nodejs:16 | grep "gcr.io/distroless/nodejs@sha256"
```

Then add it to your prod stage like this:

```Dockerfile
FROM gcr.io/distroless/nodejs@sha256:794e26246770ff28d285d7f800ce1982883cf4105662845689efa33f04ec4340 as prod
COPY --from=source --chown=1000:1000 /app /app
COPY --from=base /usr/bin/tini /usr/bin/tini
```

Remember that since it's a new image vs prior stages, you'll need to repeat any metadata that you need, including ENVs, ARGs, LABEL, EXPOSE, ENTRYPOINT, CMD, WORKDIR, or USER that you set in previous stages.

A full example of using Distroless is here: [./dockerfiles/distroless.Dockerfile](./dockerfiles/distroless.Dockerfile)

## Dockerfile best practices for Node.js

These are "better" practices really, I'll let you decide if they are "best" for you.



### Add Multi-Stage For a Single Dev-Test-Prod Dockerfile

The way I approach JIT complied languages like Node.js is to have a single Dockerfile that is used for dev, test, and prod. This is a good way to keep your images small and easy to manage. However, it means that the single Dockerfile will get more complex.

General Dockerfile flow of stages:

1. base: all prod dependencies, no code yet
2. dev, from base: all dev dependencies, no code yet (in dev, source code is bind-mounted anyway)
3. source, from base: add code
4. test, from source: copy in dev dependencies, run tests
5. prod, from source: no change from source stage, but listed last so in case a stage isn't targeted, the builder will default to this stage

`--target dev` for local development where you bind-mount into the container
`--target test` for automated CI testing, like unit tests and npm audit
`--target prod` for running on servers, with no devDependencies included, and no "uninstalls" or removing things to slim down

Note, if you're using a special prod image like distroless, the `prod` stage is where you COPY in your app from the `source` stage.

### Use `npm ci --only=production` first, then layer dev/test on top

In the `base` stage above, you'll want to copy in your package files and only install production dependencies, using npm's `ci` command that will only reference the lock file for which exact versions to install. Apparently it's faster than `npm install`.

Then you'll install devDependencies in a future stage, but `ci` doesn't support dev-only dependency install, so you'll need to use `npm install --only=development` in the `dev` stage.

## Add multi-architecture builds

Now that Apple M1's are mainstream, and Windows arm64 laptops are catching up, it's the perfect time for you to build not just x86_64 (amd64) images, but also build arm64/v8 as well, at the same time.

With Docker Desktop, you can build and push multiple architectures at once.

```shell
# if you haven't created a new custom builder instance, run this once:
docker buildx create --use

# now build and push an image for two architectures:
docker buildx build -f dockerfile/5.Dockerfile --target prod --name <account/repo>:latest --platform=linux/amd64,linux/arm64 .
```

A better way is to build in automation on every pull request push, and every push to a release branch. Docker has a [GitHub Action that's great for this](https://github.com/marketplace/actions/build-and-push-docker-images).

## Proper Node.js shutdown

This topic deserves more importance, as many tend to assume it'll all work out when you're doing production rolling updates.

But, can you be sure that, once your container runtime has ask the container to stop, that:

- DB transactions are complete
- Incoming connections have completed and gracefully closed (in )